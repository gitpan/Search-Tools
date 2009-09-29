package Search::Tools::XML;
use strict;
use warnings;
use Carp;
use base qw( Search::Tools::Object );
use Search::Tools;    # XS required

our $VERSION = '0.28';

=pod

=head1 NAME

Search::Tools::XML - methods for playing nice with XML and HTML

=head1 SYNOPSIS

 use Search::Tools::XML;
 
 my $class = 'Search::Tools::XML';
 
 my $text = 'the "quick brown" fox';
 
 my $xml = $class->start_tag('foo');
 
 $xml .= $class->utf8_safe( $text );
 
 $xml .= $class->end_tag('foo');
 
 # $xml: <foo>the &#34;quick brown&#34; fox</foo>
 
 $xml = $class->escape( $xml );
 
 # $xml: &lt;foo&gt;the &amp;#34;quick brown&amp;#34; fox&lt;/foo&gt;
 
 $xml = $class->unescape( $xml );
 
 # $xml: <foo>the "quick brown" fox</foo>
 
 my $plain = $class->no_html( $xml );
 
 # $plain eq $text
 
 
=head1 DESCRIPTION

B<IMPORTANT:> The API for escape() and unescape() has changed as of version 0.16.
The text is no longer modified in place, as this was less intuitive.

Search::Tools::XML provides utility methods for dealing with XML and HTML.
There isn't really anything new here that CPAN doesn't provide via HTML::Entities
or similar modules. The difference is convenience: the most common methods you
need for search apps are in one place with no extra dependencies.

B<NOTE:> To get full UTF-8 character set from chr() you must be using Perl >= 5.8.
This affects things like the unescape* methods.

=head1 VARIABLES
 
=head2 %HTML_ents

Complete map of all named HTML entities to their decimal values.

=cut

# regexp for what constitutes whitespace in an HTML doc
# it's not as simple as \s|&nbsp; so we define it separately

# NOTE that the pound sign # needs escaping because we use
# the 'x' flag in our regexp.

my @whitesp = (
    '&\#0020;', '&\#0009;', '&\#000C;', '&\#200B;', '&\#2028;', '&\#2029;',
    '&nbsp;',   '&\#32;',   '&\#160;',  '\s',       '\xa0',     '\x20',
);

my $whitespace = join( '|', @whitesp );

# HTML entity table
# this just removes a dependency on another module...

our %HTML_ents = (
    quot     => 34,
    amp      => 38,
    apos     => 39,
    'lt'     => 60,
    'gt'     => 62,
    nbsp     => 160,
    iexcl    => 161,
    cent     => 162,
    pound    => 163,
    curren   => 164,
    yen      => 165,
    brvbar   => 166,
    sect     => 167,
    uml      => 168,
    copy     => 169,
    ordf     => 170,
    laquo    => 171,
    not      => 172,
    shy      => 173,
    reg      => 174,
    macr     => 175,
    deg      => 176,
    plusmn   => 177,
    sup2     => 178,
    sup3     => 179,
    acute    => 180,
    micro    => 181,
    para     => 182,
    middot   => 183,
    cedil    => 184,
    sup1     => 185,
    ordm     => 186,
    raquo    => 187,
    frac14   => 188,
    frac12   => 189,
    frac34   => 190,
    iquest   => 191,
    Agrave   => 192,
    Aacute   => 193,
    Acirc    => 194,
    Atilde   => 195,
    Auml     => 196,
    Aring    => 197,
    AElig    => 198,
    Ccedil   => 199,
    Egrave   => 200,
    Eacute   => 201,
    Ecirc    => 202,
    Euml     => 203,
    Igrave   => 204,
    Iacute   => 205,
    Icirc    => 206,
    Iuml     => 207,
    ETH      => 208,
    Ntilde   => 209,
    Ograve   => 210,
    Oacute   => 211,
    Ocirc    => 212,
    Otilde   => 213,
    Ouml     => 214,
    'times'  => 215,
    Oslash   => 216,
    Ugrave   => 217,
    Uacute   => 218,
    Ucirc    => 219,
    Uuml     => 220,
    Yacute   => 221,
    THORN    => 222,
    szlig    => 223,
    agrave   => 224,
    aacute   => 225,
    acirc    => 226,
    atilde   => 227,
    auml     => 228,
    aring    => 229,
    aelig    => 230,
    ccedil   => 231,
    egrave   => 232,
    eacute   => 233,
    ecirc    => 234,
    euml     => 235,
    igrave   => 236,
    iacute   => 237,
    icirc    => 238,
    iuml     => 239,
    eth      => 240,
    ntilde   => 241,
    ograve   => 242,
    oacute   => 243,
    ocirc    => 244,
    otilde   => 245,
    ouml     => 246,
    divide   => 247,
    oslash   => 248,
    ugrave   => 249,
    uacute   => 250,
    ucirc    => 251,
    uuml     => 252,
    yacute   => 253,
    thorn    => 254,
    yuml     => 255,
    OElig    => 338,
    oelig    => 339,
    Scaron   => 352,
    scaron   => 353,
    Yuml     => 376,
    fnof     => 402,
    circ     => 710,
    tilde    => 732,
    Alpha    => 913,
    Beta     => 914,
    Gamma    => 915,
    Delta    => 916,
    Epsilon  => 917,
    Zeta     => 918,
    Eta      => 919,
    Theta    => 920,
    Iota     => 921,
    Kappa    => 922,
    Lambda   => 923,
    Mu       => 924,
    Nu       => 925,
    Xi       => 926,
    Omicron  => 927,
    Pi       => 928,
    Rho      => 929,
    Sigma    => 931,
    Tau      => 932,
    Upsilon  => 933,
    Phi      => 934,
    Chi      => 935,
    Psi      => 936,
    Omega    => 937,
    alpha    => 945,
    beta     => 946,
    gamma    => 947,
    delta    => 948,
    epsilon  => 949,
    zeta     => 950,
    eta      => 951,
    theta    => 952,
    iota     => 953,
    kappa    => 954,
    lambda   => 955,
    mu       => 956,
    nu       => 957,
    xi       => 958,
    omicron  => 959,
    pi       => 960,
    rho      => 961,
    sigmaf   => 962,
    sigma    => 963,
    tau      => 964,
    upsilon  => 965,
    phi      => 966,
    chi      => 967,
    psi      => 968,
    omega    => 969,
    thetasym => 977,
    upsih    => 978,
    piv      => 982,
    ensp     => 8194,
    emsp     => 8195,
    thinsp   => 8201,
    zwnj     => 8204,
    zwj      => 8205,
    lrm      => 8206,
    rlm      => 8207,
    ndash    => 8211,
    mdash    => 8212,
    lsquo    => 8216,
    rsquo    => 8217,
    sbquo    => 8218,
    ldquo    => 8220,
    rdquo    => 8221,
    bdquo    => 8222,
    dagger   => 8224,
    Dagger   => 8225,
    bull     => 8226,
    hellip   => 8230,
    permil   => 8240,
    prime    => 8242,
    Prime    => 8243,
    lsaquo   => 8249,
    rsaquo   => 8250,
    oline    => 8254,
    frasl    => 8260,
    euro     => 8364,
    image    => 8465,
    weierp   => 8472,
    real     => 8476,
    trade    => 8482,
    alefsym  => 8501,
    larr     => 8592,
    uarr     => 8593,
    rarr     => 8594,
    darr     => 8595,
    harr     => 8596,
    crarr    => 8629,
    lArr     => 8656,
    uArr     => 8657,
    rArr     => 8658,
    dArr     => 8659,
    hArr     => 8660,
    forall   => 8704,
    part     => 8706,
    exist    => 8707,
    empty    => 8709,
    nabla    => 8711,
    isin     => 8712,
    notin    => 8713,
    ni       => 8715,
    prod     => 8719,
    'sum'    => 8721,
    'minus'  => 8722,
    lowast   => 8727,
    radic    => 8730,
    prop     => 8733,
    infin    => 8734,
    ang      => 8736,
    'and'    => 8743,
    'or'     => 8744,
    cap      => 8745,
    cup      => 8746,
    int      => 8747,
    there4   => 8756,
    sim      => 8764,
    cong     => 8773,
    asymp    => 8776,
    ne       => 8800,
    equiv    => 8801,
    le       => 8804,
    ge       => 8805,
    sub      => 8834,
    sup      => 8835,
    nsub     => 8836,
    sube     => 8838,
    supe     => 8839,
    oplus    => 8853,
    otimes   => 8855,
    perp     => 8869,
    sdot     => 8901,
    lceil    => 8968,
    rceil    => 8969,
    lfloor   => 8970,
    rfloor   => 8971,
    lang     => 9001,
    rang     => 9002,
    loz      => 9674,
    spades   => 9824,
    clubs    => 9827,
    hearts   => 9829,
    diams    => 9830,
);

my %char2entity = ();
while ( my ( $e, $n ) = each(%HTML_ents) ) {
    my $char = chr($n);
    $char2entity{$char} = "&$e;";
}
delete $char2entity{q/'/};    # only one-way decoding

# Fill in missing entities
# TODO does this only work under latin1 locale?
for ( 0 .. 255 ) {
    next if exists $char2entity{ chr($_) };
    $char2entity{ chr($_) } = "&#$_;";
}

=head1 METHODS

The following methods may be accessed either as object or class methods.

=head2 new

Create a Search::Tools::XML object.

=cut

=head2 tag_re

Returns a qr// regex for matching a SGML (XML, HTML, etc) tag.

=cut

sub tag_re {qr/<[^>]+>/s}

=head2 html_whitespace

Returns a regex for all whitespace characters and
HTML whitespace entities.

=cut

sub html_whitespace {$whitespace}

=head2 char2ent_map

Returns a hash reference to the class data mapping chr() values to their
numerical entity equivalents.

=cut

sub char2ent_map { \%char2entity }

=head2 looks_like_html( I<string> )

Returns true if I<string> appears to have HTML-like markup in it.

Aliases for this method include:

=over

=item looks_like_xml

=item looks_like_markup

=back

=cut

sub looks_like_html { return $_[1] =~ m/[<>]|&[\#\w]+;/o }
*looks_like_xml    = \&looks_like_html;
*looks_like_markup = \&looks_like_html;

=head2 start_tag( I<string> )

=head2 end_tag( I<string> )

Returns I<string> as a tag, either start or end. I<string> will be escaped for any non-valid
chars using tag_safe().

=cut

sub start_tag { "<" . tag_safe( $_[1] ) . ">" }
sub end_tag   { "</" . tag_safe( $_[1] ) . ">" }

=pod

=head2 tag_safe( I<string> )

Create a valid XML tag name, escaping/omitting invalid characters.

Example:

	my $tag = Search::Tools::XML->tag_safe( '1 * ! tag foo' );
    # $tag == '______tag_foo'

=cut

sub tag_safe {
    my $t = pop;

    return '_' unless length $t;

    $t =~ s/[^-\.\w]/_/g;
    $t =~ s/^(\d)/_$1/;

    return $t;
}

=pod

=head2 utf8_safe( I<string> )

Return I<string> with special XML chars and all
non-ASCII chars converted to numeric entities.

This is escape() on steroids. B<Do not use them both on the same text>
unless you know what you're doing. See the SYNOPSIS for an example.

=head2 escape_utf8

Alias for utf8_safe().

=cut

*escape_utf8 = \&utf8_safe;

sub utf8_safe {
    my $t = pop;
    $t = '' unless defined $t;

    # converts all low chars except \t \n and \r
    # to space because XML spec disallows <32
    $t =~ s,[\x00-\x08\x0b-\x0c\x0e-\x1f], ,g;

    $t =~ s{([^\x09\x0a\x0d\x20\x21\x23-\x25\x28-\x3b\x3d\x3F-\x5B\x5D-\x7E])}
            {'&#'.(ord($1)).';'}eg;

    return $t;
}

=head2 no_html( I<text> )

no_html() is a brute-force method for removing all tags and entities
from I<text>. A simple regular expression is used, so things like
nested comments and the like will probably break. If you really
need to reliably filter out the tags and entities from a HTML text, use
HTML::Parser or similar.

I<text> is returned with no markup in it.

=cut

sub no_html {
    my $class = shift;
    my $text  = shift;
    if ( !defined $text ) {
        croak "text required";
    }
    my $re = $class->tag_re;
    $text =~ s,$re,,g;
    $text = $class->unescape($text);
    return $text;
}

=head2 strip_html

An alias for no_html().

=cut

*strip_html = \&no_html;

=head2 escape( I<text> )

Similar to escape() functions in more famous CPAN modules, but without the 
added dependency. escape() will convert the special XML chars (><'"&) to their
named entity equivalents.

The escaped I<text> is returned.

B<IMPORTANT:> The API for this method has changed as of version 0.16. I<text> 
is no longer modified in-place.

As of version 0.27 escape() is written in C/XS for speed.

=cut

sub escape {
    my $text = pop;
    return unless defined $text;
    return _escape_xml($text);
}

=head2 unescape( I<text> )

Similar to unescape() functions in more famous CPAN modules, but without the added
dependency. unescape() will convert all entities to their chr() equivalents.

B<NOTE:> unescape() does more than reverse the effects of escape(). It attempts
to resolve B<all> entities, not just the special XML entities (><'"&).

B<IMPORTANT:> The API for this method has changed as of version 0.16. 
I<text> is no longer modified in-place.

=cut

sub unescape {
    my $text = pop;
    $text = unescape_named($text);
    $text = unescape_decimal($text);
    return $text;
}

=head2 unescape_named( I<text> )

Replace all named HTML entities with their chr() equivalents.

Returns modified copy of I<text>.

=cut

sub unescape_named {
    my $t = pop;
    if ( defined($t) ) {

        # named entities - check first to see if it is worth looping
        if ( $t =~ m/&[a-zA-Z]+;/ ) {
            for ( keys %HTML_ents ) {
                if ( my $n = $t =~ s/&$_;/chr($HTML_ents{$_})/eg ) {

                    #warn "replaced $_ -> $HTML_ents{$_} $n times in text";
                }
            }
        }
    }
    return $t;
}

=head2 unescape_decimal( I<text> )

Replace all decimal entities with their chr() equivalents.

Returns modified copy of I<text>.

=cut

sub unescape_decimal {
    my $t = pop;

    # resolve numeric entities as best we can
    $t =~ s/&#(\d+);/chr($1)/ego if defined($t);
    return $t;
}

1;
__END__

=head1 AUTHOR

Peter Karman C<< <karman@cpan.org> >>

Originally based on the HTML::HiLiter regular expression building code, 
by the same author, copyright 2004 by Cray Inc.

Thanks to Atomic Learning C<www.atomiclearning.com> 
for sponsoring the development of these modules.

=head1 BUGS

Please report any bugs or feature requests to C<bug-search-tools at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Search-Tools>.  
I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Search::Tools


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Search-Tools>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Search-Tools>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Search-Tools>

=item * Search CPAN

L<http://search.cpan.org/dist/Search-Tools/>

=back

=head1 COPYRIGHT

Copyright 2006-2009 by Peter Karman.

This package is free software; you can redistribute it and/or modify it under the 
same terms as Perl itself.

=head1 SEE ALSO

HTML::HiLiter, SWISH::HiLiter, Rose::Object, Class::XSAccessor, Text::Aspell

=cut
