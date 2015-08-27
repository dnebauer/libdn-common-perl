requires 'perl', '5.014002';
requires 'autodie';
requires 'Config::Simple';
requires 'Carp';
requires 'Curses';
requires 'Cwd';
requires 'Data::Dumper::Simple';
requires 'Data::Structure::Util';
requires 'Data::Validate::URI';
requires 'Date::Simple';
requires 'DateTime';
requires 'DateTime::Format::Mail';
requires 'DateTime::TimeZone';
requires 'Desktop::Detect';
requires 'Email::Valid';
requires 'English';
requires 'Env';
requires 'experimental';
requires 'File::Basename';
requires 'File::chdir';
requires 'File::Copy';
requires 'File::Copy::Recursive';
requires 'File::Find::Rule';
requires 'File::MimeInfo';
requires 'File::Path';
requires 'File::Spec';
requires 'File::Temp';
requires 'File::Util';
requires 'File::Which';
requires 'Function::Parameters';
requires 'Gtk2::Notify';
requires 'HTML::Entities';
requires 'IO::Pager';
requires 'IPC::Cmd';
requires 'IPC::Open3';
requires 'IPC::Run';
requires 'List::MoreUtils';
requires 'Logger::Syslog';
requires 'Moo';
requires 'MooX::HandlesVia';
requires 'namespace::clean';
requires 'Net::DBus';
requires 'Net::Ping::External';
requires 'Proc::ProcessTable';
requires 'Readonly';
requires 'Scalar::Util';
requires 'Storable';
requires 'strictures';
requires 'Term::ANSIColor';
requires 'Term::Clui';
requires 'Term::ReadKey';
requires 'Test::NeedsDisplay';
requires 'Text::Pluralize';
requires 'Text::Wrap';
requires 'Time::HiRes';
requires 'Time::Simple';
requires 'Type::Utils';
requires 'Types::Path::Tiny';
requires 'Types::Standard';
requires 'UI::Dialog';
requires 'version';

on test => sub {
    requires 'Test::More', '0.96';
};
