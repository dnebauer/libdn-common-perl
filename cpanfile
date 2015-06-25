requires 'perl', '5.0';
requires 'Getopt::Declare';
requires 'File::Which';
requires 'File::Copy';
requires 'File::MimeInfo';
requires 'Term::ANSIColor';
requires 'Text::Wrap';
requires 'Config::Simple';
requires 'Net::Ping::External';
requires 'Proc::ProcessTable';
requires 'Dn::Menu';
requires 'File::Util';
requires 'File::Basename';
requires 'Cwd';
requires 'Date::Simple';
requires 'Term::Clui';
requires 'Storable';
requires 'Term::ReadKey';
requires 'Gtk2::Notify';
requires 'Logger::Syslog';

build_requires 'Gtk2::TestHelper';

on test => sub {
    requires 'Test::More', '0.96';
};
