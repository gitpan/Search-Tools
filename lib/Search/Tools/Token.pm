package Search::Tools::Token;
use strict;
use warnings;
use Carp;
use overload
    '""'     => sub { $_[0]->str; },
    'bool'   => sub { $_[0]->len; },
    fallback => 1;

use Search::Tools;    # XS required

our $VERSION = '0.57';

1;

__END__

=head1 NAME

Search::Tools::Token - a token object returned from a TokenList

=head1 SYNOPSIS

 use Search::Tools::Tokenizer;
 my $tokenizer = Search::Tools::Tokenizer->new();
 my $tokens = $tokenizer->tokenize('quick brown red dog');
 while ( my $token = $tokens->next ) {
     # token isa Search::Tools::Token
     print "token = $token\n";
     printf("str: %s, len = %d, u8len = %d, pos = %d, is_match = %d, is_hot = %d\n",
        $token->str,
        $token->len, 
        $token->u8len, 
        $token->pos, 
        $token->is_match, 
        $token->is_hot
     );
 }

=head1 DESCRIPTION

A Token represents one or more characters culled from a string by a Tokenizer.

=head1 METHODS

Most of Search::Tools::Token is written in C/XS so if you view the source of
this class you will not see much code. Look at the source for Tools.xs and
search-tools.c if you are interested in the internals, or look at
Search::Tools::TokenPP.

=head2 str

The characters in the token. Stringifies to the str() value with overloading.

=head2 len

The byte length of str().

=head2 u8len

The character length of str(). For ASCII, len() == u8len(). For non-ASCII
UTF-8, u8len() < len().

=head2 pos

The zero-based position in the original string.

=head2 is_match

Did the token match the re() in the Tokenizer.

=head2 is_hot

Did the token match the heat_seeker in the Tokenizer.

=head2 is_sentence_start

Returns true value if the Token starts with an UPPER case
UTF8 character or other common sentence-starting character.

=head2 is_sentence_end

Returns true value if the Token matches common sentence-ending
punctuation.

=head2 dump

Prints the internal XS attributes to stderr.

=head2 set_hot

Set the is_hot() value.

=head2 set_match

Set the is_match() value.

=head1 AUTHOR

Peter Karman C<< <karman@cpan.org> >>

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

Copyright 2009 by Peter Karman.

This package is free software; you can redistribute it and/or modify it under the 
same terms as Perl itself.
