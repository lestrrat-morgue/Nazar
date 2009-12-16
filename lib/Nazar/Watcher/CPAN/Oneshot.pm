package Nazar::Watcher::CPAN::Oneshot;
use Moose;
use AnyEvent::HTTP;
use JSON;
use namespace::autoclean;

extends 'Nazar::Watcher::CPAN::FriendFeed';

sub start {
    my ($self, $nazar) = @_;

    http_get 'http://friendfeed-api.com/v2/feed/cpan', sub {
        my $feed = JSON::decode_json($_[0]);
OUTER:
        foreach my $entry ( @{ $feed->{entries} } ) {
            $self->enqueue_if_applicable( $entry );
        }
    };

    warn "started to watch cpan feed (oneshot)";
}

__PACKAGE__->meta->make_immutable();

1;