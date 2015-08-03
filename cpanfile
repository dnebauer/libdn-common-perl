requires 'perl', '5.014002';
requires 'autodie';
requires 'Config::Simple';
requires 'Carp';
requires 'Curses';
requires 'Cwd';
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
requires 'IPC::Cmd';
requires 'IPC::Open3';
requires 'IPC::Run';
requires 'Logger::Syslog';
requires 'MooseX::MakeImmutable';
requires 'Moose';
requires 'MooseX::MakeImmutable';
requires 'namespace::autoclean';
requires 'Net::DBus';
requires 'Net::Ping::External';
requires 'Proc::ProcessTable';
requires 'Readonly';
requires 'Scalar::Util';
requires 'Storable';
requires 'Term::ANSIColor';
requires 'Term::Clui';
requires 'Term::ReadKey';
requires 'Test::NeedsDisplay';
requires 'Text::Wrap';
requires 'Time::Simple';
requires 'Time::Zone';
requires 'Type::Utils';
requires 'Types::Standard';
requires 'UI::Dialog';

on test => sub {
    requires 'Test::More', '0.96';
};
