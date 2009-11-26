
package Nazar::Watcher::CPAN::Realtime;
use Moose;
use AnyEvent::FriendFeed::Realtime;
use namespace::clean -except => qw(meta);

extends 'Nazar::Watcher::CPAN::FriendFeed';

has username => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has remote_key => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);


sub start {
    my ($self, $nazar) = @_;

    my $client; $client = AnyEvent::FriendFeed::Realtime->new(
        username => $self->username,
        remote_key => $self->remote_key,
        request => "/feed/cpan",
        on_error => sub {
            undef $client;
            $self->start($nazar);
        },
        on_entry => sub {
            $self->enqueue_if_applicable( @_ );
        }
    );
    warn "started to watch cpan feed";
}

__PACKAGE__->meta->make_immutable();

1;
