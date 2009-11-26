
package Nazar::Watcher::CPAN::FriendFeed;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Nazar::Watcher';

has exclude => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
);

sub _build_exclude {
    return [ '^Test-System', '^Apache2?-' ];
}

sub enqueue_if_applicable {
    my ($self, $entry) = @_;
    my $body = $entry->{body};
    if ( $entry->{body} =~ /^([\w\-]+) ([0-9\._]*) by (.+?) - <a.*href="(http:.*?\.tar\.gz)"/ ) {
        my %data = (
            dist => $1,
            version => $2,
            author => $3,
            uri => $4,
        );

        foreach my $rule ( @{ $self->exclude } ) {
            next OUTER if ($data{dist} =~ /$rule/);
        }
        $self->context->queue_get( "CPAN" )->item_push( \%data );
    }
}

__PACKAGE__->meta->make_immutable();

1;