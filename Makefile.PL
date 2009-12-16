use inc::Module::Install;

name 'Nazar';
all_from 'lib/Nazar.pm';

requires 'CPAN::Inject';
requires 'Moose';
requires 'AnyEvent::FriendFeed::Realtime';
requires 'AnyEvent::HTTP';
requires 'AnyEvent::MP';
requires 'AnyEvent::MP::Global';
requires 'AnyEvent::Util';
requires 'AnyEvent';
requires 'Cwd';
requires 'File::Copy';
requires 'File::Temp';
requires 'File::Temp';
requires 'JSON';
requires 'Moose';
requires 'MooseX::Types::Path::Class';
requires 'POSIX';
requires 'Scalar::Util';
requires 'URI::Escape';
requires 'namespace::autoclean';


WriteAll;
