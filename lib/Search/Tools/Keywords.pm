package Search::Tools::Keywords;

use strict;
use warnings;
use base qw( Search::Tools::Object );

# make sure we get correct ->utf8 encoding
use POSIX qw(locale_h);
use locale;

use Carp;
use Encode;
use Search::Tools::UTF8;
use Search::Tools::RegExp;
use Search::QueryParser;

our $VERSION = '0.23';

__PACKAGE__->mk_accessors(
    qw(
        and_word
        or_word
        not_word
        ),
    @Search::Tools::Accessors
);

sub _init {
    my $self = shift;
    $self->SUPER::_init(@_);

    # set defaults
    $self->{locale} ||= setlocale(LC_CTYPE);
    ( $self->{lang}, $self->{charset} ) = split( m/\./, $self->{locale} );
    $self->{lang} = 'en_US' if $self->{lang} =~ m/^(posix|c)$/i;
    $self->{charset}           ||= 'iso-8859-1';
    $self->{phrase_delim}      ||= '"';
    $self->{and_word}          ||= 'and|near\d*';
    $self->{or_word}           ||= 'or';
    $self->{not_word}          ||= 'not';
    $self->{wildcard}          ||= '*';
    $self->{stopwords}         ||= [];
    $self->{ignore_first_char} ||= $Search::Tools::RegExp::IgnFirst;
    $self->{ignore_last_char}  ||= $Search::Tools::RegExp::IgnLast;
    $self->{word_characters}   ||= $Search::Tools::RegExp::WordChar;
    $self->{debug}             ||= $ENV{PERL_DEBUG} || 0;
    $self->{ignore_case} = 1 unless defined $self->{ignore_case};

}

sub extract {
    my $self      = shift;
    my $query     = shift or croak "need query to extract keywords";
    my $stopwords = $self->stopwords;
    my $and_word  = $self->and_word;
    my $or_word   = $self->or_word;
    my $not_word  = $self->not_word;
    my $wildcard  = $self->wildcard;
    my $phrase    = $self->phrase_delim;
    my $igf       = $self->ignore_first_char;
    my $igl       = $self->ignore_last_char;
    my $wordchar  = $self->word_characters;

    my $esc_wildcard = quotemeta($wildcard);
    my $word_re      = qr/([$wordchar]+($esc_wildcard)?)/;
    my @query        = @{ ref $query ? $query : [$query] };
    $stopwords = [ split( /\s+/, $stopwords ) ] unless ref $stopwords;
    my %stophash
        = map { to_utf8( lc($_), $self->charset ) => 1 } @$stopwords;
    my ( %words, %uniq, $c );
    my $parser = Search::QueryParser->new(
        rxAnd => qr{$and_word}i,
        rxOr  => qr{$or_word}i,
        rxNot => qr{$not_word}i,
    );

Q: for my $q (@query) {
        $q = lc($q) if $self->ignore_case;
        $q = to_utf8( $q, $self->charset );
        my $p = $parser->parse( $q, 1 );
        $self->debug && carp "parsetree: " . pp($p);
        $self->_get_v( \%uniq, $p, $c );
    }

    $self->debug && carp "parsed: " . pp( \%uniq );

    my $count = scalar( keys %uniq );

    # parse uniq into word tokens
    # including removing stop words

    $self->debug && carp "word_re: $word_re";

U: for my $u ( sort { $uniq{$a} <=> $uniq{$b} } keys %uniq ) {

        my $n = $uniq{$u};

        # only phrases have space
        # but due to our word_re, a single non-spaced string
        # might actually be multiple word tokens
        my $isphrase = $u =~ m/\s/ || 0;

        $self->debug && carp "$u -> isphrase = $isphrase";

        my @w = ();

    TOK: for my $w ( split( m/\s+/, to_utf8( $u, $self->charset ) ) ) {

            next TOK unless $w =~ m/\S/;

            $w =~ s/\Q$phrase\E//g;

            while ( $w =~ m/$word_re/g ) {
                my $tok = _untaint($1);

                # strip ignorable chars
                $tok =~ s/^[$igf]+//;
                $tok =~ s/[$igl]+$//;

                unless ($tok) {
                    $self->debug && carp "no token for '$w' $word_re";
                    next TOK;
                }

                $self->debug && carp "found token: $tok";

                if ( exists $stophash{ lc($tok) } ) {
                    $self->debug && carp "$tok = stopword";
                    next TOK unless $isphrase;
                }

                unless ($isphrase) {
                    next TOK if $tok =~ m/^($and_word|$or_word|$not_word)$/i;
                }

                # if tainting was on, odd things can happen.
                # so check one more time
                $tok = to_utf8( $tok, $self->charset );

                # final sanity check
                if ( !Encode::is_utf8($tok) ) {
                    carp "$tok is NOT utf8";
                    next TOK;
                }

                #$self->debug && carp "pushing $tok into wordlist";
                push( @w, $tok );

            }

        }

        next U unless @w;

        #$self->debug && carp "joining \@w: " . pp(\@w);
        if ($isphrase) {
            $words{ join( ' ', @w ) } = $n + $count++;
        }
        else {
            for (@w) {
                $words{$_} = $n + $count++;
            }
        }

    }

    $self->debug && carp "tokenized: " . pp( \%words );

    # make sure we don't have 'foo' and 'foo*'
    for ( keys %words ) {
        if ( $_ =~ m/$esc_wildcard/ ) {
            ( my $copy = $_ ) =~ s,$esc_wildcard,,g;

            # delete the more exact of the two
            # since the * will match both
            delete( $words{$copy} );
        }
    }

    $self->debug && carp "wildcards removed: " . pp( \%words );

    # if any words need to be stemmed
    if ( $self->stemmer ) {

        # split each $word into words
        # stem each word
        # if stem ne word, break into chars and find first N common
        # rejoin $uniq

        #carp "stemming ON\n";

    K: for ( keys %words ) {
            my (@w) = split /\s+/;
        W: for my $w (@w) {
                my $func = $self->stemmer;
                my $f = &$func( $self, $w );

                #warn "w: $w\nf: $f\n";

                if ( $f ne $w ) {

                    my @stemmed = split //, $f;
                    my @char    = split //, $w;
                    $f = '';    #reset
                    while ( @char && @stemmed && $stemmed[0] eq $char[0] ) {
                        $f .= shift @stemmed;
                        shift @char;
                    }

                }

                # add wildcard to indicate chars were lost
                $w = $f . $wildcard;
            }
            my $new = join ' ', @w;
            if ( $new ne $_ ) {
                $words{$new} = $words{$_};
                delete $words{$_};
            }
        }

    }

    $self->debug && carp "stemming done: " . pp( \%words );

    # sort keeps query in same order as we entered
    return ( sort { $words{$a} <=> $words{$b} } keys %words );

}

# stolen nearly verbatim from Taint::Runtime
# it's unclear to me why our regexp results in tainted vars.
# if we untaint $query in initial extract() set up,
# subsequent matches against word_re still end up tainted.
# might be a Unicode weirdness?
sub _untaint {
    my $str = shift;
    my $ref = ref($str) ? $str : \$str;
    if ( !defined $$ref ) {
        $$ref = undef;
    }
    else {
        $$ref
            = ( $$ref =~ /(.*)/ )
            ? $1
            : do { confess("Couldn't find data to untaint") };
    }
    return ref($str) ? 1 : $str;
}

sub _get_v {
    my $self      = shift;
    my $uniq      = shift;
    my $parseTree = shift;
    my $c         = shift;

    # we only want the values from non minus queries
    for my $node ( grep { $_ eq '+' || $_ eq '' } keys %$parseTree ) {
        my @branches = @{ $parseTree->{$node} };

        for my $leaf (@branches) {
            my $v = $leaf->{value};

            if ( ref $v ) {
                $self->_get_v( $uniq, $v, $c );
            }
            else {

                # collapse any whitespace
                $v =~ s,\s+,\ ,g;

                $uniq->{$v} = ++$c;
            }
        }
    }

}

1;

__END__

=pod

=head1 NAME

Search::Tools::Keywords - extract keywords from a search query

=head1 SYNOPSIS

 use Search::Tools::Keywords;
 use Search::Tools::RegExp;
 
 my $query = 'the quick fox color:brown and "lazy dog" not jumped';
 
 my $kw = Search::Tools::Keywords->new(
            stopwords           => 'the',
            and_word            => 'and',
            or_word             => 'or',
            not_word            => 'not',
            stemmer             => &your_stemmer_here,       
            ignore_first_char   => '\+\-',
            ignore_last_char    => '',
            word_characters     => $Search::Tools::RegExp::WordChar,
            debug               => 0,
            phrase_delim        => '"',
            charset             => 'iso-8859-1',
            lang                => 'en_US',
            locale              => 'en_US.iso-8859-1'
            );
            
 my @words = $kw->extract( $query );
 # returns:
 #   quick
 #   fox
 #   brown
 #   lazy dog
 
 
=head1 DESCRIPTION

B<Do not confuse this class with Search::Tools::RegExp::Keywords.>

Search::Tools::Keywords extracts the meaningful words from a search
query. Since many search engines support a syntax that includes special
characters, boolean words, stopwords, and fields, search queries can become
complicated. In order to separate the wheat from the chafe, the supporting
words and symbols are removed and just the actual search terms (keywords)
are returned.

This class is used internally by Search::Tools::RegExp. You probably don't need
to use it directly. But if you do, read on.

=head1 METHODS

=head2 new( %opts )

The new() method instantiates a S::T::K object. With the exception
of extract(), all the following methods can be passed as key/value
pairs in new().
 
=head2 extract( I<query> )

The extract method parses I<query> and returns an array of meaningful words.
I<query> can either be a scalar string or an array reference (if multiple queries
should be parsed simultaneously).

Only positive words are extracted. In other words, if you search for:

 foo not bar
 
then only C<foo> is returned. Likewise:

 +foo -bar
 
would return only C<foo>.

B<NOTE:> All queries are converted to UTF-8. See the C<charset> param.

=head2 stemmer

The stemmer function is used to find the root 'stem' of a word. There are many
stemming algorithms available, including many on CPAN. The stemmer function
should expect to receive two parameters: the Keywords object and the word to be
stemmed. It should return exactly one value: the stemmed word.

Example stemmer function:

 use Lingua::Stem;
 my $stemmer = Lingua::Stem->new;
 
 sub mystemfunc
 {
     my ($kw,$word) = @_;
     return $stemmer->stem($word)->[0];
 }
 
 # and pass to Keywords new() method:
 
 my $keyword_obj = Search::Tools::Keyword->new(stemmer => \&mystemfunc);
     
=head2 stopwords

A list of common words that should be ignored in parsing out keywords. 
May be either a string that will be split on whitespace, or an array ref.

B<NOTE:> If a stopword is contained in a phrase, then the phrase 
will be tokenized into words based on whitespace, then the stopwords removed.

=head2 ignore_first_char

String of characters to strip from the beginning of all words.

=head2 ignore_last_char

String of characters to strip from the end of all words.

=head2 ignore_case

All queries are run through Perl's built-in lc() function before
parsing. The default is C<1> (true). Set to C<0> (false) to preserve
case.

=head2 and_word

Default: C<and|near\d*>

=head2 or_word

Default: C<or>

=head2 not_word

Default: C<not>

=head2 wildcard

Default: C<*>

=head2 locale

Set a locale explicitly for a Keywords object.If not set, 
the locale is inherited from the C<LC_CTYPE> environment
variable.

=head2 lang

Base language. If not set, extracted from C<locale> or defaults to C<en_US>.

=head2 charset

Base charset used for converting queries to UTF-8. If not set, 
extracted from C<locale> or defaults to C<iso-8859-1>.

=head1 AUTHOR

Peter Karman C<perl@peknet.com>

Based on the HTML::HiLiter regular expression building code, 
originally by the same author, 
copyright 2004 by Cray Inc.

Thanks to Atomic Learning C<www.atomiclearning.com> 
for sponsoring the development of this module.

=head1 COPYRIGHT

Copyright 2006 by Peter Karman. 
This package is free software; you can redistribute it and/or modify it under the 
same terms as Perl itself.

=head1 SEE ALSO

HTML::HiLiter, Search::QueryParser
