package Dn::Common;

use Moose;
use 5.014_002;
use version; our $VERSION = qv('1.0.5');

use namespace::autoclean;
use Test::NeedsDisplay;    # enables Gtk2::Notify to compile
use Function::Parameters;
use Carp;
use Readonly;
use Try::Tiny;
use Fatal qw(open close);
use English qw(-no_match_vars);

Readonly my $TRUE          => 1;
Readonly my $FALSE         => 0;
Readonly my $ICON_ERROR    => '@pkgdata_dir@/error.xpm';
Readonly my $ICON_WARN     => '@pkgdata_dir@/warn.xpm';
Readonly my $ICON_QUESTION => '@pkgdata_dir@/question.xpm';
Readonly my $ICON_INFO     => '@pkgdata_dir@/info.xpm';

# dependencies

use File::Util;

use File::Which;

use File::Basename;

use File::Copy;

use Cwd qw/ abs_path getcwd/;

use File::MimeInfo ();

use Date::Simple;

use Term::ANSIColor;

use Term::Clui;
$ENV{'CLUI_DIR'} = "OFF";    # do not remember responses

use Text::Wrap;

use Storable;

use Config::Simple;

use Term::ReadKey;

use Net::Ping::External qw(ping);

use Gtk2::Notify -init, "$0";

use Net::DBus;

use Proc::ProcessTable;

use Config::Simple;

use Logger::Syslog;

use Dn::Menu;

use Desktop::Detect qw(detect_desktop);

# attributes
has 'script' => (
    is      => 'ro',
    default => sub { File::Util->new()->strip_path($0); },
);

has 'kde_running' => (
    is      => 'ro',
    default => sub {
        ( Desktop::Detect->detect_desktop()->{desktop} eq 'kde-plasma' )
            ? $TRUE
            : $FALSE;
    },
);

has 'screensaver' => (
    is      => 'rw',
    isa     => 'Net::DBus::RemoteObject',
    default => sub {
        Net::DBus->session->get_service('org.freedesktop.ScreenSaver')
            ->get_object('/org/freedesktop/ScreenSaver');
    },
);
has 'screensaver_cookie' => ( is => 'rw', );

has 'screensaver_attempt_suspend' => (
    is      => 'rw',
    default => sub {
        ( Desktop::Detect->detect_desktop()->{desktop} eq 'kde-plasma' )
            ? $TRUE
            : $FALSE;
    },
);

has '_configs_files' => (
    is      => 'rw',
    isa     => 'ArrayRef[Config::Simple]',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        _add_config_file      => 'push',        # add_config_file($obj)
        _config_file_iterator => 'natatime',    # iterator
    },
    documentation => 'hold configuration file objects',
);

has '_processed_config_files' => (
    is            => 'rw',
    isa           => 'Bool',
    default       => $FALSE,
    documentation => 'flag whether config files processed',
);

has 'processes' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
    handles => {

        # add_process($pid, $cmd)
        add_process => 'set',

        # get_command($pid) -> $cmd
        get_command => 'get',

        # clear_processes()
        clear_processes => 'clear',

        # pids() -> @pids
        # ascending sort: 'sort { $a <=> $b } $x->pids()'
        pids => 'keys',

        # commands() -> @commands
        # ascending sort: 'sort { $a <=> $b } $x->commands()'
        commands => 'values',

        # used in regenerating processes hash
        _processes_pair_list => 'kv',

        # has_processes() -> true|false
        has_processes => 'count',

        # no_processes() -> true|false
        no_processes => 'is_empty',
    },
);

method _read_config_files () {
    $self->_processed_config_files($TRUE);    # flag files as processed
    my $root = File::Util->new()->strip_path($PROGRAM_NAME);

    # set directory and filename possibilities to try
    my ( @dirs, @files );
    push @dirs,  $ENV{'PWD'};                      # ./     == bash $( pwd )
    push @dirs,  "/usr/local/etc";                 # /usr/local/etc/
    push @dirs,  "/etc";                           # /etc/
    push @dirs,  sprintf( "/etc/%s", $root );      # /etc/FOO/
    push @dirs,  $ENV{'HOME'};                     # ~/     == bash $HOME
    push @files, sprintf( "%sconfig", $root );     # FOOconfig
    push @files, sprintf( "%sconf", $root );       # FOOconf
    push @files, sprintf( "%s.config", $root );    # FOO.config
    push @files, sprintf( "%s.conf", $root );      # FOO.conf
    push @files, sprintf( "%src", $root );         # FOOrc
    push @files, sprintf( ".%src", $root );        # .FOOrc

    # look for existing combinations and capture those config files
    for my $dir (@dirs) {
        for my $file (@files) {
            my $cf = sprintf "%s/%s", $dir, $file;
            if ( -r "$cf" ) {
                $self->_add_config_file( Config::Simple->new($cf) );
            }
        }
    }
}

method config_param ($param) {

    # set and check variables
    if ( not $param ) { return; }
    my @values;

    # read config files if not already done
    if ( not $self->_processed_config_files ) { $self->_read_config_files; }

    # cycle through config files looking for matches
    # - later matches override earlier matches
    # - force list context initially
    my $iterator = $self->_config_file_iterator(1);
    while ( my $config_file = $iterator->() ) {
        if ( $config_file->param($param) ) {
            @values = $config_file->param($param);
        }
    }
    return (wantarray) ? @values : "@values";
}

sub _load_processes {

    # load 'processes' attribute with pid=>command pairs
    # params: 0 = class
    # return: nil
    my ($self) = (shift);
    if ( $self->has_processes() ) { $self->clear_processes() }
    foreach my $process ( @{ Proc::ProcessTable->new()->table() } ) {
        $self->add_process( $process->pid, $process->cmndline );
    }
}

sub get_processes {

    # reconstruct processes hash
    # params: 0 = class
    # return: hashref
    my ( $self, %processes ) = (shift);
    if ( $self->no_processes() ) { return; }
    my @processes_array = $self->_processes_pair_list();
    foreach my $process (@processes_array) {
        $processes{ $process->[0] } = $process->[1];
    }
    return \%processes;
}

has 'configs' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
    handles => {

        # add_config($key, $val)
        add_config => 'set',

        # get_config($key, ...) -> $val
        config => 'get',

        # clear_configs()
        clear_configs => 'clear',

        # keys() -> @configs
        # ascending sort: 'sort { $a <=> $b } $x->keys()'
        keys => 'keys',

        # values() -> @configs
        # ascending sort: 'sort { $a <=> $b } $x->values()'
        values => 'values',

        # used in regenerating configs hash
        _configs_pair_list => 'kv',

        # has_configs() -> true|false
        has_configs => 'count',

        # no_configs() -> true|false
        no_configs => 'is_empty',
    },
);

sub get_configs {

    # reconstruct configs hash
    # params: 0 = class
    # return: hashref
    my ( $self, %configs ) = (shift);
    if ( $self->no_configs() ) { return; }
    my @configs_array = $self->_configs_pair_list();
    foreach my $config (@configs_array) {
        $configs{ $config->[0] } = $config->[1];
    }
    return \%configs;
}

# methods

sub suspend_screensaver {

    # suspends kde screensaver
    # params: 0 = class
    # return: nil
    # note:   $PID provided by 'English' module
    my ($self) = (shift);
    if ( $self->screensaver_attempt_suspend ) {
        try {
            $self->screensaver_cookie(
                $self->screensaver->Inhibit( $PID, "running $self->keyword" )
            );
            $self->info('Inhibited screensaver');
        }
        catch {
            $self->alert('Failed to suspend screensaver');
            $self->screensaver_attempt_suspend($FALSE);
        }
    }
    else {
        $self->alert('Cannot suspend screensaver on non-KDE desktop');
    }
    return;
}

sub restore_screensaver {

    # restores kde screensaver
    # params: 0 = class
    # return: nil
    my ($self) = (shift);
    if ( $self->screensaver_attempt_suspend ) {
        try {
            $self->screensaver->UnInhibit( $self->screensaver_cookie );
            $self->alert('Restored screensaver');
        }
        catch {
            $self->alert('Unable to restore screensaver programmatically');
            $self->alert(
                'It should restore automatically as this script exits');
        }
    }
    return;
}

sub notify {

    # display message to user
    # optionally prepend script name
    # params: 0  = class
    #         1  = prepend (boolean, optional) OR msg
    #         2+ = message
    my ( $self, $prefix ) = ( shift, '' );
    my ( $name, @args ) = ( $self->script, @_ );
    if ( $self->is_boolean( $args[0] ) ) {
        my $prepend = $self->boolise(shift);
        if ($prepend) {
            $prefix = "$name: ";
        }
    }
    for my $msg (@args) {
        printf "%s$msg\n", $prefix;
    }
}

sub sc_notify {

    # display message to user with script name prepended
    # params: 0  = class
    #         1+ = message
    my ( $self, @args ) = ( shift, @_ );
    if ( $self->is_boolean( $args[0] ) ) {
        shift @args;    # may be FALSE
    }
    unshift @args, $TRUE;    # force TRUE to force scriptname prefix
    $self->notify(@args);
}

sub notify_sys {

    # display message to user in system notification area
    # params: 0 = class
    #         1 = hashref => (
    #               msg   => required,
    #               title => optional, default = calling script name
    #               type  => 'info'|'question'|'warn'|'error'
    #                        optional, default = 'info'
    #               icon  => filepath, optional, default = type icon
    #               time  => msec, optional, default = 10,000
    # return: boolean, whether able to display notification
    # usage:  $cp->notify_sys( {
    #             title => 'Outcome', msg   => 'Operation successful!'
    #          } );
    # alert:  do not call this method from a spawned child process --
    #         the 'show()' call in the last line of this method causes
    #         the child process to hang without any feedback to user

    # get arguments
    my ( $self, $params ) = ( shift, shift );
    my ( $name, $icon ) = ( $self->script );
    if ( not ref $params eq 'HASH' ) {
        return;
    }
    if ( not $params->{'msg'} ) {
        return;
    }

    # set parameters
    $params->{'title'} = $name if not $params->{'title'};
    $params->{'time'}  = 10000 if not $params->{'time'};
    if ( $params->{'icon'} and -f $params->{'icon'} ) {
        $icon = $params->{'icon'};
    }
    else {
        my %valid_type = map { ( $_ => 1 ) } qw( info question warn error );
        $params->{'type'} = 'info' if not $params->{'type'};
        if ( not $valid_type{ $params->{'type'} } ) {
            $params->{'type'} = 'info';
        }
        $icon
            = ( $params->{'type'} eq 'info' ) ? $ICON_INFO
            : ( $params->{'type'} eq 'question' ) ? $ICON_QUESTION
            : ( $params->{'type'} eq 'warn' )     ? $ICON_WARN
            :                                       $ICON_ERROR;
    }

    # display notification popup
    my $n = Gtk2::Notify->new( $params->{'title'}, $params->{'msg'}, $icon );
    $n->set_timeout( $params->{'time'} );
    $n->show();
}

=head3 logger()

Display message in system log.

There are four message types: 'debug', 'notice', 'warning' and 'error'. One of the method parameters specifies message type -- if none is specified the default message type 'notify' is used. The method will die if an invalid message type is passed.

Not all message types appear in all system logs. On Debian, for example, /var/log/messages records only notice and warning log messages while /var/log/syslog records all log messages.

Parameters: [ 0 = class ] , 1 = message , 2 = message type (case-insensitive, optional, default = 'notice').

Examples:

    $cp->logger( "Widget started" );
    $cp->logger( "Widget died unexpectedly!" , "error" );

Return type: Boolean (whether able to display notification).

=cut

sub logger {
    my ( $self, $message, $type ) = ( shift, shift, shift );
    my @types = qw/ debug notice warning error /;
    $type = 'notice' if not $type;    # default
    $type =~ s/(.*)/\L$1/g;           # lowercase
    die "Invalid log message type '$type'" unless grep /^$type$/, @types;

    # switch: $type
    # case: 'debug'
    ( grep $type eq $_, qw/ debug / ) and do { debug($message); };

    # case: 'notice'
    ( grep $type eq $_, qw/ notice / ) and do { notice($message); };

    # case: 'warning'
    ( grep $type eq $_, qw/ warning / ) and do { warning($message); };

    # case: 'error'
    ( grep $type eq $_, qw/ error / ) and do { error($message); };

    # note: no default case needed since $type was checked earlier
    # endswitch
}

=head3 abort()

Abort script with error message. Message may be prepended with scriptname and the associated method 'sc_abort' is also available (see method 'notify' for the logic used). 

Parameters: [ 0 = class ] , 1 = prepend (boolean, optional) , 1|2 = message ,
                            2 = message ...

Return type: N/A.

=cut

sub abort {
    my ( $name, $self, $prepend ) = ( $_[0]->scriptname(), shift );
    $self->notify(@_);
    $prepend = $self->boolise(shift) if $self->is_boolean( $_[0] );
    die sprintf( "%sborting\n", ($prepend) ? "$name: a" : 'A' );
}

sub sc_abort {
    my $self = shift;
    my @args = @_;      # next, ensure first arg is prepend boolean
    unshift @args, $TRUE if not $self->is_boolean( $args[0] );
    $args[0] = $TRUE;    # force pre-existing prepend boolean to true
    $self->abort(@args);
}

=head3 clear_screen()

Clear the terminal screen.

Parameters: (0 = class).

Returns: NIL.

=cut

sub clear_screen { system "clear"; }

=head3 input_choose()

User selects from a menu. The scriptname may be prepended to the prompt and the associated method 'sc_input_choose' is also available (see method 'notify' for the logic used).

Returns user's selection.

Parameters: (0 = class), 1 = prepend (boolean, optional) , 1|2 = prompt,
                         2|3+ = options.

Return type: Scalar.

Common usage:

    my $value = undef;
    while ( 1 ) {
        $value = $self->input_choose( "Select value:" , <@list> );
        if ( $value ) { last; }
        print "Invalid choice. Sorry, please try again.\n";
    }

=cut

sub input_choose {
    my ( $name, $self, $prepend ) = ( $_[0]->scriptname(), shift );
    $prepend = $self->boolise(shift) if $self->is_boolean( $_[0] );
    my $prompt = shift;
    $prompt = "$name: $prompt" if $prepend;
    Term::Clui::choose( $prompt, @_ );
}

sub sc_input_choose {
    my $self = shift;
    my @args = @_;      # next, ensure first arg is prepend boolean
    unshift @args, $TRUE if not $self->is_boolean( $args[0] );
    $args[0] = $TRUE;    # force pre-existing prepend boolean to true
    $self->input_choose(@args);
}

=head3 input_ask()

User enters a value. The scriptname may be prepended to the prompt and the associated method 'sc_input_ask' is also available (see method 'notify' for the logic used).

This method is intended for entering short values. Once the entered text wraps to a new line the user cannot move the cursor back to the previous line.

Use method 'input_large' if the value is likely to be longer than a single line.

Returns user's input.

Parameters: (0 = class), 1 = prepend (boolean, optional) , 1|2 = prompt,
                         2|3 = default.

Return type: Scalar (text).

Common usage:

    my $value = undef;
    while ( 1 ) {
        $value = $self->input_ask( "Enter value:" , <$default> );
        if ( $self->_is_valid_value( $value ) ) { last; }
    }

=cut

sub input_ask {
    my ( $name, $self, $prepend ) = ( $_[0]->scriptname(), shift );
    $prepend = $self->boolise(shift) if $self->is_boolean( $_[0] );
    my ( $prompt, $default ) = ( shift, shift );
    $prompt = "$name: $prompt" if $prepend;
    Term::Clui::ask( $prompt, $default );
}

sub sc_input_ask {
    my $self = shift;
    my @args = @_;      # next, ensure first arg is prepend boolean
    unshift @args, $TRUE if not $self->is_boolean( $args[0] );
    $args[0] = $TRUE;    # force pre-existing prepend boolean to true
    $self->input_ask(@args);
}

=head3 input_large()

User enters data. The scriptname may be prepended to the prompt and the associated method 'sc_input_large' is also available (see method 'notify' for the logic used).

This method is intended for entry of data likely to be longer than a single line. Use method 'input_ask' if entering a simple (short) value. An editor is used to enter the data. The default editor is used. If no default editor is set, vi(m) is used.

When the editor opens it displays some boilerplate, the prompt, a horizontal rule (a line of dashes), and the default value if provided. When the editor is closed all lines up to and including the first horizontal rule are deleted. The user can get the same effect by deleting in the editor all lines up to and including the first horizontal rule.

Returns user's input. Note that newlines are left in the return value unchanged.

Parameters: (0 = class), 1 = prepend (boolean, optional) , 1|2 = prompt,
                         2|3 = default.

Return type: Scalar (text).

Common usage:

    my $value = undef;
    while ( 1 ) {
        $value = $self->input_large( "Enter value:" , <$default> );
        last if $self->_is_valid_value( $value );
    }

To convert multi-line data to a single line:

    my $value = undef;
    while ( 1 ) {
        $value = join " " ,
                 split( "\n" , $self->input_large( "Value:" , <$default> ) );
        last if $self->_is_valid_value( $value );
    }

=cut

sub input_large {
    my ( $name, $self, $prepend ) = ( $_[0]->scriptname(), shift );
    $prepend = $self->boolise(shift) if $self->is_boolean( $_[0] );
    my ( $prompt, $default ) = ( shift, shift );
    $prompt = "$name: $prompt" if $prepend;
    $default = "" if not $default;
    my ( $index, $rule_index ) = ( 1, 0 );
    my $rule = "-" x 60;
    my $content
        = "[Everything to first horizontal rule will be deleted]\n"
        . $prompt . "\n"
        . $rule . "\n"
        . $default;
    my @data = split "\n", Term::Clui::edit( $prompt, $content );

    foreach (@data) {
        chomp;
        $rule_index = $index if $_ =~ /^-+$/;
        $index++;
    }
    join "\n", @data[ $rule_index .. $#data ];
}

sub sc_input_large {
    my $self = shift;
    my @args = @_;      # next, ensure first arg is prepend boolean
    unshift @args, $TRUE if not $self->is_boolean( $args[0] );
    $args[0] = $TRUE;    # force pre-existing prepend boolean to true
    $self->input_large(@args);
}

=head3 input_confirm()

User answers y/n to a question. The scriptname may be prepended to the question and the associated method 'sc_input_confirm' is also available (see method 'notify' for the logic used).

If the question is multi-line, after the answer is supplied only the first line is left on screen. The first line should be a short summary question with subsequent lines holding further information.

Parameters: (0 = class), 1 = prepend (boolean , optional) , 1|2 = question.

Return type: Boolean.

Common usage:

    if ( input_confirm( "Short question?\n\nMore\nmulti-line\ntext." ) ) {
        # do stuff
    }

=cut

sub input_confirm {
    my ( $name, $self, $prepend ) = ( $_[0]->scriptname(), shift );
    $prepend = $self->boolise(shift) if $self->is_boolean( $_[0] );
    my $question = shift;
    $question = "$name: $question" if $prepend;
    Term::Clui::confirm($question);
}

sub sc_input_confirm {
    my $self = shift;
    my @args = @_;      # next, ensure first arg is prepend boolean
    unshift @args, $TRUE if not $self->is_boolean( $args[0] );
    $args[0] = $TRUE;    # force pre-existing prepend boolean to true
    $self->input_confirm(@args);
}

=head3 display()

Displays screen text with word wrapping.

Parameters: (0 = class), 1 = display string.

Common usage:

    display( <$scalar> );

=cut

sub display { print Text::Wrap::wrap( "", "", $_[1] . "\n" ); }

=head3 pecho()

Wrapper for bash 'echo' command.

Parameters: (0 = class), 1 = display string.

Common usage:

    pecho( <$scalar> );

=cut

sub pecho { system "echo", "-e", $_[1]; }

=head3 pechon()

Wrapper for bash 'echo -n' command.

Parameters: (0 = class), 1 = display string.

Common usage:

    pechon( <$scalar> );

=cut

sub pechon { system "echo", "-en", $_[1]; }

=head3 underline()

Wrap text in bash formatting codes that result in underlining.

Parameters: (0 = class), 1 = display string.

Common usage:

    underline( '<text>' );

=cut

sub underline {
    my ( $self, $text ) = ( shift, shift );
    sprintf "%s%s%s", $self->uline_on(), $text, $self->uline_off();
}

=head3 vim_print()

Print text to terminal screen using vim's default colour scheme.

Five styles have been implemented:

             Vim
             Highlight
    Style    Group       Foreground    Background
    -------  ----------  ------------  ----------
    title    Title       bold magenta  normal
    error    ErrorMsg    bold white    red
    warning  WarningMsg  red           normal
    prompt   MoreMsg     bold green    normal
    normal   Normal      normal        normal

You can supply one or more strings as an array reference in the first parameter. If you are supplying only one string it can be passed as a simple scalar.

Supplied strings can contain escaped double quotes.

The 'type' parameter is case-insensitive. You can type any or all of the type parameter -- as little as one character is sufficient. If the type parameter is invalid the text is printed as normal with no error generated.

Uses module Term::ANSIColor.

Examples:

    $cp->vim_print( [ "This is a title" ] , 't' );
    $cp->vim_print( "This is normal text" );
    $cp->vim_print( [ "Error message" ] , 'Err' );
    $cp->vim_print( [ "This is normal text" ] , 'N' );
    my @warnings = ( "This is a list of warning messages" ,
                     "It will be passed by reference"
    );
    $cp->vim_print( \@warnings , 'Warn' );
    $cp->vim_print( "This is a prompt" , 'PROMPT' );

Parameters: [ 0 = class ] , 1 = message(s) (scalar|arrayref) , 2 = type ('title'|'error'|'warning'|'prompt'|'normal') (optional) (default = 'normal')

Return type: N/A.

=cut

sub vim_print {

    # variables
    my ( $self, $msg, $type, @messages ) = ( shift, shift, shift );

    # - was it a single message string or an array reference?
    push @messages, $msg unless ref $msg;    # string
    @messages = @{$msg} if ref $msg eq 'ARRAY';    # arrayref
          # - if type is undefined it causes an error on matching
       # - if type set to empty string it matches on every, therefore first, match
    $type = 'x' if not $type;

    # print text
    # - note: partial matching of text types works because they all start
    #         with a different letter
    if ( 'title' =~ /^$type/i ) {    # title
        for (@messages) {
            print colored "$_", 'bold', 'magenta';
            print "\n";
        }
    }
    elsif ( 'error' =~ /^$type/i ) {    # error
        for (@messages) {
            print colored "$_", 'bold', 'white', 'on_red';
            print "\n";
        }
    }
    elsif ( 'warning' =~ /^$type/i ) {    # warning
        for (@messages) {
            print colored "$_", 'bright_red';
            print "\n";
        }
    }
    elsif ( 'prompt' =~ /^$type/i ) {     # prompt
        for (@messages) {
            print colored "$_", 'bold', 'bright_green';
            print "\n";
        }
    }
    else {                                # normal
        for (@messages) {
            print "$_";
            print "\n";
        }
    }
}

=head3 vim_printify()

Modifies a single string to be included in a List to be passed to the 'vim_list_printify' method. The string is given a prefix that signals to 'vim_list_printify' what format to use. The prefix is stripped before the string is printed.

Five styles have been implemented:

             Vim
             Highlight
    Style    Group       Foreground    Background
    -------  ----------  ------------  ----------
    title    Title       bold magenta  normal
    error    ErrorMsg    bold white    red
    warning  WarningMsg  red           normal
    prompt   MoreMsg     bold green    normal
    normal   Normal      normal        normal

Supplied strings can contain escaped double quotes.

The 'type' parameter is case-insensitive. You can type any or all of the type parameter -- as little as one character is sufficient. If the type parameter is invalid the text is printed as normal with no error generated.

Uses module Term::ANSIColor.

Examples:

    push @output , $cp->vim_printify( "Title" , 't' );
    push @output , $cp->vim_printify( "Normal text" );
    push @output , $cp->vim_printify( "Error message" , 'Err' );
    push @output , $cp->vim_printify( "Normal text" , 'N' );
    push @output , $cp->vim_printify( "Warning message" , 'Warning' );
    push @output , $cp->vim_printify( "Prompt" , 'PROMPT' );
    $cp->vim_list_print( \@output );

Parameters: [ 0 = class ] , 1 = message , 2 = type ('title'|'error'|'warning'|'prompt'|'normal') (optional) (default = 'normal')

Return type: N/A.

=cut

sub vim_printify {

    # variables
    my ( $self, $message, $type, $token ) = ( shift, shift, shift );

   # - if type is undefined it causes an error on matching
   # - if type set to empty string it matches on every, therefore first, match
    $type = 'x' if not $type;

    # get prefix token
    # - note: partial matching of text types works because they all start
    #         with a different letter
    if    ( 'title' =~ /^$type/i )   { $token = '::title::'; }
    elsif ( 'error' =~ /^$type/i )   { $token = '::error::'; }
    elsif ( 'warning' =~ /^$type/i ) { $token = '::warn::'; }
    elsif ( 'prompt' =~ /^$type/i )  { $token = '::prompt::'; }
    else                             { $token = ''; }

    # return altered string
    return sprintf( "%s%s", $token, $message );
}

=head3 vim_list_print()

Prints a list of strings to the terminal screen using vim's default colour scheme.

Five styles have been implemented:

             Vim
             Highlight
    Style    Group       Foreground    Background
    -------  ----------  ------------  ----------
    title    Title       bold magenta  normal
    error    ErrorMsg    bold white    red
    warning  WarningMsg  red           normal
    prompt   MoreMsg     bold green    normal
    normal   Normal      normal        normal

Supplied strings can contain escaped double quotes.

Each element of the list can be printed in a different style. Element strings need to be prepared using the 'vim_printify' method. See the 'vim_printify' method for an example.

Parameters: [ 0 = class ] , 1 = array reference.

Return type: N/A.

=cut

sub vim_list_print {

    # variables
    my ( $self, $lines_ref, $line, @lines ) = ( shift, shift );

    # - gracefully handle simple string in place of arrayref
    push @lines, $lines_ref unless ref $lines_ref;    # string
    @lines = @{$lines_ref} if ref $lines_ref eq 'ARRAY';    # arrayref
                                                            # print output
    foreach (@lines) {
        if ( $_ =~ /^::title::/ ) {                         # title
            $self->vim_print( substr( $_, 9 ), 't' );
        }
        elsif ( $_ =~ /^::error::/ ) {                      # error
            $self->vim_print( substr( $_, 9 ), 'e' );
        }
        elsif ( $_ =~ /^::warn::/ ) {                       # warning
            $self->vim_print( substr( $_, 8 ), 'w' );
        }
        elsif ( $_ =~ /^::prompt::/ ) {                     # prompt
            $self->vim_print( substr( $_, 10 ), 'p' );
        }
        else {                                              # normal
            $self->vim_print("$_");
        }
    }
}

=head3 browse()

Displays large volume of text in default editor and then returns viewer to original screen.

Parameters: (0 = class), 1 = title , 2 = text.

Common usage:

    browse( <$title> , <$text> );

=cut

sub browse {
    my ( $self, $title, $body ) = ( shift, shift, shift );
    my $text
        = "\n"
        . $title . "\n\n"
        . "[This text should be displaying in your default editor.\n"
        . " If no default editor is specified, vi(m) is used.\n"
        . " To exit this screen, exit the editor as you normally would"
        . " - 'ZQ' for vi(m).]" . "\n\n"
        . $body;
    Term::Clui::edit( $title, $text );
}

=head3 prompt()

Display message and prompt user to press any key.  Default message: 'Press any key to continue'.

Parameters: [ 0 = class ] , 1 = message (optional).

Returns: NIL.

=cut

sub prompt {
    my ( $self, $prompt, $key ) = ( shift, shift );
    $prompt = 'Press any key to continue... ' if not $prompt;
    print $prompt;
    ReadMode('raw');
    while (1) {
        $key = ReadKey(0);
        last if defined $key;
    }
    ReadMode('restore');
    print "\n";
}

=head3 get_path()

Return path from filepath.

Parameters: [ 0 = class ] , 1 = filepath.

Return type: String.

=cut

sub get_path { File::Util->new()->return_path( $_[1] ); }

=head3 executable_path()

Return path of executable. Mimics bash 'which' utility. Returns absolute path to executable if executable exists. If executable does not exist, it returns undef.

Parameters: [ 0 = class ] , 1 = executable name.

Return type: String.

=cut

sub executable_path { which( $_[1] ); }

=head3 make_dir()

Make directory recursively.

Parameters: [ 0 = class ] , 1 = dirpath.

Return type: String.

=cut

sub make_dir {
    File::Util->new()->make_dir( $_[1], '--if-not-exists' )
        or die "Unable to create '$_[1]': $!";
}

=head3 files_list()

List files in directory. Uses current directory if no directory is supplied.

Parameters: [ 0 = class ] , 1 = dirpath (optional).

Return type: Array reference.

=cut

sub files_list {
    my ( $self, $dir, $files_list ) = ( shift, shift, () );
    $dir = $self->cwd() if not $dir;
    $dir = $self->true_path("$dir");
    $files_list
        = [ File::Util->new()->list_dir( "$dir" => { files_only => $TRUE } ) ]
        or die "Unable to get file listing from '$_[1]': $!";
    return $files_list;
}

=head3 dirs_list()

List subdirectories in directory. Uses current directory if no directory is supplied.

Parameters: [ 0 = class ] , 1 = dirpath (optional).

Return type: Array reference.

=cut

sub dirs_list {
    my ( $self, $dir, $dirs_list ) = ( shift, shift, () );
    $dir = $self->cwd() if not $dir;
    $dir = $self->true_path("$dir");
    $dirs_list
        = [ File::Util->new()->list_dir( "$dir" => { dirs_only => $TRUE } ) ]
        or die "Unable to get directory listing from '$_[1]': $!";
    shift @{$dirs_list};
    shift @{$dirs_list};    # remove '.' and '..'
    return $dirs_list;
}

=head3 backup_file()

Backs up file by renaming it to a unique file name. Will simply add integer to file basename.

Uses 'move' function from File::Copy.

Parameters: [ 0 = class ] , 1 = file.

Return type: N/A.

=cut

sub backup_file {
    my ( $file, $count, $backup ) = ( shift, 1 );

    # determine backup file name
    my ( $base, $suffix ) = ( fileparse( $file, qr/\.[^.]*$/ ) )[ 0, 2 ];
    $backup = $base . '_' . $count++ . $suffix;
    while ( -e $backup ) { $backup = $base . '_' . $count++ . $suffix; }

    # do backup
    move( $file, $backup )
        or die "Error: unable to backup $base to $backup\n";
    printf "Existing file '%s' renamed to '%s'\n", $file, $backup;
}

=head3 listify()

Designed for functions where arguments may be passed as a sequence of scalars, an array (which is handled as a sequence of scalars), or an array reference. The methood can handle a mixture of scalars and array references.

Any other type of reference is ignored, though a warning is printed.

Parameters: [ 0 = class ] , 1+ = array_ref|scalar.

Return type: Array reference.

=cut

sub listify {
    my ( $self, $simple_array, @args ) = (shift);

    # assemble arguments
    while (@_) {
        local $_ = shift;
        if ( ref $_ ) {    # argument is a reference
            if ( ref $_ eq 'ARRAY' ) {    # is array reference
                    # all elements in the referenced array must be scalar -
                    # there can be no nested references -
                    # referenced arrays containing nested references
                    # will be ignored
                $simple_array = $TRUE;
                foreach my $element ( @{$_} ) {
                    $simple_array = $FALSE if ref $element;
                }
                if ($simple_array) {

                    # then reference is to uncomplicated array
                    # and we add to the arguments array all the elements
                    # in the referenced array
                    push @args, @{$_};
                }
                else {
                    # reference is to a complicated array that contains
                    # elements that are themselves references to other data
                    # structures - ignore this array reference
                    warn "Referenced array itself includes references\n";
                    warn "- this is not permitted\n";
                    warn "- referenced array is being ignored\n";
                }
            }
            else {
                # reference is to structure other than array - ignore it
                warn "Invalid argument " . ref $_ . " ref";
            }
        }
        else {
            # argument is a scalar
            push @args, $_;
        }
    }
    return [] unless @args;    # no arguments derived
    return \@args;             # return array reference
}

=head3 adb_run()

A major problem with adb is that it does not return an error code if an operation fails. This method runs an adb command, traps the error code, converts it to perl semantics, and returns it.

Any error messages are printed to the console. 

The preferred parameter is an array reference, but the method tries to gracefully handle strings and arrays. If the method encounters a reference other than ARRAY it will be ignored and an error message printed.

If the parameters are processed and no command elements are derived from them, an error message is printed and an error code returned.

Parameters: [ 0 = class ] , 1 = array_ref|scalar , 2+ = array_ref|scalar.

Return type: Boolean.

=cut

sub adb_run {
    my ( $self, $bash_exit_code, $succeeded, @output, @cmd ) = (shift);

    # assemble command elements
    #while ( @_ ) {
    #    local $_ = shift;
    #    if ( ref $_ ) {
    #        if ( ref $_ eq 'ARRAY' ) { push @cmd , @{ $_ }; }  # array ref
    #        else { warn "Invalid argument " . ref $_ . " ref"; } # other ref
    #    }
    #    else { push @cmd , $_; }  # scalar
    #}
    @cmd = @{ $self->listify(@_) };
    return $FALSE unless @cmd;

    # run command and trap error status
    @output = split /\n/, `@cmd 2>&1 ; echo \$?`;
    return $FALSE if not @output;    # should never happen
    $bash_exit_code = pop @output;
    $succeeded = ( $bash_exit_code eq 0 ) ? 1 : 0;  # perl reverses bash codes
    print "$_\n" foreach @output;                   # pass on command output
    return $succeeded;
}

=head3 adb_capture()

A major problem with adb is that it does not return an error code if an operation fails. This method runs an adb command, traps the error code, converts it to perl semantics, and returns it. It also capture any output and returns that.

Any error messages from this method are printed to the console. 

The preferred parameter is an array reference, but the method tries to gracefully handle strings and arrays. If the method encounters a reference other than ARRAY it will be ignored and an error message printed.

If the parameters are processed and no command elements are derived from them, an error message is printed and an error code returned.

Parameters: [ 0 = class ] , 1 = array_ref|scalar , 2+ = array_ref|scalar.

Return type: Array_ref [
                scalar (boolean, adb_success) ,
                array_ref (adb_output) 
]

=cut

sub adb_capture {
    my ( $self, $bash_exit_code, $succeeded, @output, @cmd ) = (shift);

    # assemble command elements
    #while ( @_ ) {
    #    local $_ = shift;
    #    if ( ref $_ ) {
    #        if ( ref $_ eq 'ARRAY' ) { push @cmd , @{ $_ }; }  # array ref
    #        else { warn "Invalid argument " . ref $_ . " ref"; } # other ref
    #    }
    #    else { push @cmd , $_; }  # scalar
    #}
    @cmd = @{ $self->listify(@_) };
    return $FALSE unless @cmd;

    # run command and trap error status
    @output = split /\n/, `@cmd 2>&1; echo \$?`;
    return $FALSE if not @output;    # should never happen
    $bash_exit_code = pop @output;
    $succeeded = ( $bash_exit_code eq 0 ) ? 1 : 0;  # perl reverses bash codes
    return [ $succeeded, \@output ];
}

=head3 valid_positive_integer()

Determine whether supplied value is a valid positive integer (zero or above).

Parameters: [ 0 = class ] , 1 = value.

Return type: Boolean.

=cut

sub valid_positive_integer {
    my ( $self, $val ) = ( shift, shift );
    return $TRUE if $val =~ /^0$/;
    return $TRUE if $val =~ /^[1-9]\d*$/;
    return $FALSE;
}

=head3 today()

Return today as an ISO-formatted date.

Parameters: [ 0 = class ].

Return type: String.

=cut

sub today { Date::Simple->today()->format('%Y-%m-%d'); }

=head3 offset_date()

Return as an ISO-formatted date a date offset from today. The offset can be a positive or negative integer.

Parameters: [ 0 = class ] , 1 = offset.

Return type: String.

=cut

sub offset_date { Date::Simple->today() + $_[1]; }

=head3 day_of_week()

Return day of week that supplied date falls on. Note that supplied date must be in ISO format. Default date: today.

Parameters: [ 0 = class ] , 1 = date (optional).

Return type: Scalar <string>.

=cut

sub day_of_week {

    # get date
    my ( $self, $date, $d, $day ) = ( shift, shift );
    $date = $self->today() if not $date;
    return undef if not $self->valid_date($date);

    # derive day of week
    $d   = Date::Simple->new($date);
    $day = (
        'Sunday',   'Monday', 'Tuesday', 'Wednesday',
        'Thursday', 'Friday', 'Saturday'
    )[ $d->day_of_week() ];
    $day = undef if not $day;
    $day;
}

=head3 konsolekalendar_date_format()

Return date formatted in same manner as konsolekalendar does in its output. An example date value is 'Tues, 15 Apr 2008'. The corresponding strftime format string is '%a, %e %b %Y'. Note that supplied date must be in ISO format. Default date: today.

Parameters: [ 0 = class ] , 1 = date (optional).

Return type: Scalar <string>.

=cut

sub konsolekalendar_date_format {

    # get date
    my ( $self, $date, $d, $format ) = ( shift, shift );
    $date = $self->today() if not $date;
    return undef if not $self->valid_date($date);

    # reformat
    $format = '%a, %e %b %Y';
    $d      = Date::Simple->new($date)->format($format);
    $d =~ s/  / /g;    # dates 1-9 have leading space
    $d;
}

=head3 valid_date()

Determine whether supplied date is valid.

Parameters: [ 0 = class ] , 1 = date (YYYY-MM-DD).

Return type: Boolean.

=cut

sub valid_date { ( Date::Simple->new( $_[1] ) ) ? $TRUE : $FALSE; }

=head3 sequential_dates()

Determine whether supplied dates are sequential.

Assumes both dates are formatted as ISO dates [YYY-MM-DD]. If this is not so, the results may be unpredictable.

Parameters: [ 0 = class ] , 1 = date (YYYY-MM-DD), 2 = date (YYYY-MM-DD).

Return type: Boolean.

=cut

sub sequential_dates {
    ( Date::Simple->new( $_[1] ) < Date::Simple->new( $_[2] ) );
}

=head3 future_date()

Determine whether supplied date occurs in the future, i.e, today or after today.

Assumes date is formatted as ISO date [YYY-MM-DD]. If this is not so, the results may be unpredictable.

Parameters: [ 0 = class ] , 1 = date (YYYY-MM-DD).

Return type: Boolean.

=cut

sub future_date {
    ( Date::Simple->new( $_[1] ) >= Date::Simple->today() );
}

=head3 valid_24h_time_hrs()

Provide list of valid hour values for 24-hour time.

Parameters: [ 0 = class ].

Return type: List.

=cut

sub valid_24h_time_hrs {
    my ( $self, @valid_hrs ) = (shift);
    push( @valid_hrs, $_ ) foreach 0 .. 23;
    foreach (@valid_hrs) { $_ = '0' . $_ if length($_) == 1; }
    @valid_hrs;
}

=head3 valid_24h_time_minsec()

Provide list of valid minute and second values for 24-hour time.

Parameters: [ 0 = class ].

Return type: List.

=cut

sub valid_24h_time_minsec {
    my ( $self, @valid_minsec ) = (shift);
    push( @valid_minsec, $_ ) foreach 0 .. 60;
    foreach (@valid_minsec) { $_ = '0' . $_ if length($_) == 1; }
    @valid_minsec;
}

=head3 valid_24h_time()

Determine whether supplied time is valid.

Parameters: [ 0 = class ] , 1 = time (HH:MM[:SS]).

Return type: Boolean.

=cut

sub valid_24h_time {
    my ( $self, $time ) = ( shift, shift );
    return $FALSE if not $time =~ /^\d\d:\d\d(:\d\d)?/;
    my ( $h, $m, $s ) = split /:/, $time;
    my $valid = $TRUE;
    grep /$h/, $self->valid_24h_time_hrs()    or $valid = $FALSE;
    grep /$m/, $self->valid_24h_time_minsec() or $valid = $FALSE;
    if ($s) {
        grep /$s/, $self->valid_24h_time_minsec() or $valid = $FALSE;
    }
    $valid;
}

=head3 sequential_24h_times()

Determine whether supplied times are sequential, i.e., second time occurs after first time. Assume both times are from the same day.

Parameters: [ 0 = class ] , 1 = time (HH:MM[:SS]) , 2 = time (HH:MM[:SS]).

Return type: Boolean.

=cut

sub sequential_24h_times {
    my ( $self, $t1, $t2 ) = ( shift, shift, shift );
    return $FALSE if not $self->valid_24h_time($t1);
    return $FALSE if not $self->valid_24h_time($t2);
    my ( $h1, $m1, $s1 ) = split /:/, $t1;
    my ( $h2, $m2, $s2 ) = split /:/, $t2;
    my $valid = $FALSE;
    if ( $h1 < $h2 ) {    # hour-1 < hour-2
        $valid = $TRUE;
    }
    else {
        if ( $h1 == $h2 ) {
            if ( $m1 < $m2 ) {    # hours same, min-1 < min-2
                $valid = $TRUE;
            }
            else {
                if ( $m1 == $m2 ) {
                    if ( $s1 and $s2 ) {
                        if ( $s1 < $s2 ) {  # hours & mins same, sec-1 < sec-2
                            $valid = $TRUE;
                        }
                    }
                }
            }
        }
    }
    $valid;
}

=head3 deentitise()

Perform standard conversions of HTML entities to reserved characters (see function 'entitise' for table of entities).

Parameters: [ 0 = class ] , 1 = string.

Return type: String.

=cut

sub deentitise {
    my ( $self, $val ) = ( shift, shift );
    $val =~ s/&apos;/'/g;
    $val =~ s/&quot;/"/g;
    $val =~ s/&gt;/>/g;
    $val =~ s/&lt;/</g;
    $val =~ s/&amp;/&/g;
    $val;
}

=head3 entitise()

Perform standard conversions of reserved characters to HTML entities:

    Name             ASCII     Entity
    ----             -----     ------
    ampersand          &       &amp;
    less than          <       &lt;
    greater than       >       &gt;
    quotation mark     "       &quot;
    apostrophe         '       &apos;

Parameters: [ 0 = class ] , 1 = string.

Return type: String.

=cut

sub entitise {
    my ( $self, $val ) = ( shift, shift );
    $val =~ s/&/&amp;/g;
    $val =~ s/</&lt;/g;
    $val =~ s/>/&gt;/g;
    $val =~ s/"/&quot;/g;
    $val =~ s/'/&apos;/g;
    $val;
}

=head3 entitise_apos()

Perform standard conversions of apostrophes (single quotes) to an HTML entity.

Parameters: [ 0 = class ] , 1 = string.

Return type: String.

=cut

sub entitise_apos {
    my ( $self, $val ) = ( shift, shift );
    $val =~ s/'/&apos;/g;
    $val;
}

=head3 dequote()

Remove quote marks from string.

Parameters: [ 0 = class ] , 1 = string.

Return type: String.

=cut

sub dequote {
    my ( $self, $val ) = ( shift, shift );
    $val =~ s/'|"//g;
    $val;
}

=head3 tabify()

Covert tab markers ('\t') in string to spaces. Default tab size is four spaces.

Parameters: [ 0 = class ] , 1 = string , 2 = tab_size (optional).

Return type: String.

=cut

sub tabify {
    my ( $self, $string, $tab_size, $tab ) = ( shift, shift, shift );
    $tab_size = 4 if not $tab_size;
    for ( my $i = 0; $i < $tab_size; $i++ ) { $tab .= ' '; }
    $string =~ s/\\t/$tab/g;
    $string;
}

=head3 trim()

Remove leading and trailing whitespace from string.

Parameters: [ 0 = class ] , 1 = string.

Return type: String.

=cut

sub trim {
    my ( $self, $string ) = ( shift, shift );
    $string =~ s/^\s//;
    $string =~ s/\s$//;
    $string;
}

=head3 boolise()

Convert value to boolean.

Parameters: [ 0 = class ] , 1 = value.

Return type: Boolean (integer: 0|1).

=cut

sub boolise {
    my ( $self, $val ) = ( shift, shift );
    return 0 if not defined($val);    # handle special case
    $val =~ s/(.*)/\L$1/g;                # lowercase
    $val =~ s/(^yes$|^true$|^on$)/1/;     # true -> 1
    $val =~ s/(^no$|^false$|^off$)/0/;    # false -> 0
    $val;
}

=head3 is_boolean()

Determine whether supplied value is boolean.

Parameters: [ 0 = class ] , 1 = value.

Return type: Boolean (integer: 0|1).

=cut

sub is_boolean { $_[0]->boolise( $_[1] ) =~ /(^1$|^0$)/; }

=head3 save_store()

Store data structure in file.

Parameters: [ 0 = class ] , 1 = variable reference , 2 = file.

Return type: Boolean (integer).

Common usage:

    my %functions = $self->functions();
    my $storage_dir = '/path/to/filename';
    $self->save_store( \%functions , $storage_file );

=cut

sub save_store { Storable::store $_[1], $_[2]; }

=head3 retrieve_store()

Retrieves function data from sorage file.

Parameters: [ 0 = class ] , 1 = file.

Return type: Scalar (function reference).

Common usage:

    my $storage_file = '/path/to/filename';
    my $funcref = $self->retrieve_store( $storage_file );
    $self->set_functions( $funcref );

=cut

sub retrieve_store { Storable::retrieve $_[1]; }

=head3 read_config_files()

Locates all configuration files and loads their parameters and values. Module documentation for Config::Simple give full information on various configuration file formats that can be read. Here are two simple formats that will suffice for most scripts. In each case the key is 'my_key' and the corresponding value is 'my value'.

    my_key my value
    my_key: my value

Note the value does not need to be enclosed in quotes even if it contains spaces.

If you wish to store multiple values for a single parameter, follow the instructions in the Config::Simple man|pod page for how to format the configuration file.

All values are stored as an array, even if there is only one value for a parameter. See method 'config_param' for the implications of this.

Uses script name as root of configuration file name if one is not supplied. Searches the following directories in turn (assume configuration file root is 'FOO'):

    ./ , /usr/local/etc , /etc , /etc/FOO , ~/

for the following files, in turn:

    FOOconfig , FOOconf , FOO.config , FOO.conf , FOOrc , .FOOrc

If there are multiple instances of a particular parameter in these files, only the last one read will be stored. As a result of the directory ordering a local parameter setting will override the same parameter's global setting.

Parameters: [ 0 = class ] , 1 = config file root (optional).

Return type: N/A.

=cut

sub read_config_files {

    # set file variables
    my ( $self, $root ) = ( shift, shift );
    $root = $self->scriptname() if not $root;
    $root = File::Util->new()->strip_path($0) if not $root;
    my ( @dirs, @files );
    push @dirs,  $ENV{'PWD'};                      # ./     == bash $( pwd )
    push @dirs,  "/usr/local/etc";                 # /usr/local/etc/
    push @dirs,  "/etc";                           # /etc/
    push @dirs,  sprintf( "/etc/%s", $root );      # /etc/FOO/
    push @dirs,  $ENV{'HOME'};                     # ~/     == bash $HOME
    push @files, sprintf( "%sconfig", $root );     # FOOconfig
    push @files, sprintf( "%sconf", $root );       # FOOconf
    push @files, sprintf( "%s.config", $root );    # FOO.config
    push @files, sprintf( "%s.conf", $root );      # FOO.conf
    push @files, sprintf( "%src", $root );         # FOOrc
    push @files, sprintf( ".%src", $root );        # FOO.rc
         # cycle through potential config directories ...

    for my $dir (@dirs) {

        # ... looking for config files ...
        for my $file (@files) {
            my $cf = sprintf "%s/%s", $dir, $file;

            # ... and if any are found ...
            if ( -r "$cf" ) {

                # ... extract their config parameter data ...
                # (capture error where config file is empty)
                my %cf_data = eval {
                    %{ Config::Simple->import_from( $cf, \my $del )->{'_DATA'}
                    };
                };

                # ... and add them to the config hash
                if (%cf_data) {
                    $self->add_config( "$_", $cf_data{$_} )
                        foreach sort keys %cf_data;
                }
            }
        }
    }
}

=head3 config_param()

Retrieves named parameter value from configuration settings. Looks in configuration hash created by the 'read_config_files' method. If hash is empty it automatically runs that method to populate the hash. Note that this will use the default universal configuration file root. If your script needs to use a different configuration root, call 'read_config_files' explicitly -- if no argument is given it will default to using the calling script's name as root.

All parameter values are stored internally as arrays, even if there is only one value. This method will convert a return value to a scalar if there is only one value. If there are multiple values they will be returned as a list. For this reason it is important to know how parameter values are stored when using this method to retrieve them.

If no matching parameter is found then undef is returned.

Parameters: [ 0 = class ] , 1 = param.

Return type: Scalar or List.

=cut

sub config_param {

    # set and check variables
    my ( $self, $param, @values ) = ( shift, shift, () );
    return undef if not $param;

    # get all values
    $self->read_config_files( $self->config_root() ) if not $self->configs();
    my %configs = $self->configs();

    # catch case where no matching config value
    return () unless exists $configs{$param};

    # get desired parameter value
    @values = @{ $configs{$param} };

    # return scalar or list depending on number of values
    if   ( scalar @values == 1 ) { return $values[0]; }
    else                         { return @values; }
}

=head3 uline()

Underline text.

Parameters: [ 0 = class ] , 1 = string.

Return type: Scalar (string).

=cut

sub uline {
    my ( $self, $string ) = ( shift, shift );
    sprintf( "%s%s%s", $self->uline_on(), $string, $self->uline_off() );
}

=head3 number_list()

Take list and prefix each element with element index. Index is left padded with spaces so each is the same length.

Example: 'Item' becomes ' 9. Item'.

Parameters: [ 0 = class ] , 1 = list.

Return type: List.

=cut

sub number_list {
    shift;
    my ( $index, $length ) = ( 1, length scalar @_ );
    map { ' ' x ( $length - length $index ) . $index++ . '. ' . $_ }
        map {$_} @_;
}

=head3 denumber_list()

Take list and remove any number prefixes added with method 'number_list'.

Example: ' 9. Item' becomes 'Item'.

Parameters: [ 0 = class ] , 1 = list.

Return type: List.

=cut

sub denumber_list {
    shift;
    map { s/^[ ]*\d+\.[ ](.+)$/$1/; $_ } map {$_} @_;
}

=head3 shorten()

Truncate text with ellipsis if too long.

Parameters: [ 0 = class ] , 1 = string , 2 = limit ,
                            3 = continuation character (default: ellipsis).

Return type: Scalar (string).

=cut

sub shorten {
    my ( $string, $limit, $cont, $ellipsis )
        = ( shift, shift, shift, shift, "\x{2026}" );
    $cont = $ellipsis if not $cont;
    $string = substr( $string, 0, $limit - 1 ) . $ellipsis
        if length($string) > $limit;
    $string;
}

=head3 internet_connection()

Checks to see whether an internet connection can be found. Checks connection to a number of sites supplied by libdncommon-vars.

Parameters: [ 0 = class ].

Return type: Boolean.

=cut

sub internet_connection {
    my ( $self, $connected ) = ( shift, $FALSE );
    my @ping_urls = $self->config_param('ping_urls')
        or die "No ping urls retrieved from config files,\nstopped";

    # following contraction of the following code works
    # but it returns the compilation error:
    # "possible precedence issue with control flow operator"
    #return ping( hostname => $_ ) and last foreach @ping_urls;
    foreach (@ping_urls) {
        if ( ping( hostname => $_ ) ) {
            $connected = $TRUE;
            last;
        }
    }
    return $connected;
}

=head3 process_fs_mount_file()

Reads mount file and stores information on mounted filesystems.

Credit: based on Linux::Mounts perl module by Stephane Chmielewski <snck@free.fr>.

Parameters: [ 0 = class ] , 1 = mount_file (optional).

Return type: N/A.

=cut

sub process_fs_mount_file {

    # set variables
    my ( $self, $file ) = ( shift, shift );
    $file = $self->fs_mount_file() if not $file;

    # clear any existing mount file data
    $self->_clear_fs_mounts();

    # read in mount file and store data
    if ( -e $file || -f $file ) {
        if ( open( MOUNTS, $file ) ) {
            while (<MOUNTS>) {
                chomp;
                $self->_add_fs_mount( split(/\s/) );
            }
        }
        close(MOUNTS);
    }
}

=head3 cwd()

Provides current directory.

Uses 'getcwd' from package Cwd.

Parameters: [ 0 = class ].

Return type: Scalar (dirpath).

=cut

sub cwd { Cwd::getcwd(); }

=head3 true_path()

Converts relative to absolute filepaths. Any filepath can be provided to this method -- if an absolute filepath is provided it is returned unchanged. Symlinks will be followed and converted to their true filepaths.

If the directory part of the filepath does not exist the entire filepath is returned unchanged. This is a compromise. There may be times when you want to normalise a non-existent path, i.e, to collapse '../' parent directories. The 'abs_path' function can handle a filepath with a nonexistent file. Unfortunately, however, it will silently return an empty result if an invalid directory is included in the path. Since safety should always take priority, the method will return the supplied filepath unchanged if the directory part does not exist.

WARNING: If passing a variable to this function it should be double quoted. If not, passing a value like './' results in an error as the value is somehow reduced to an empty value.

Parameters: [ 0 = class ] , 1 = filepath , 2 = base (optional).

Return type: Scalar (filepath).

=cut

sub true_path {

    # set and check variables
    my ( $self, $fp ) = ( shift, shift );

    # abort if invalid directory path because causes abs_path to fail
    return $fp if not -e $self->get_path($fp);

    # do conversion
    return abs_path($fp);
}

=head3 mounted_filesystems()

Returns list of mounted filesystems.

Will run 'process_fs_mount_file' if this has not already occurred. Note that this method will be invoked without an argument so it will use the default mount file. If your script needs to use a different mount file, make sure to run 'process_fs_mount_file' explicitly before calling 'get_mounted_filesystems'.

This method is based on an assumption that the mount file has at least one entry in it. On modern Linux systems that will always be true.

Credit: based on Linux::Mounts perl module by Stephane Chmielewski <snck@free.fr>.

Parameters: [ 0 = class ].

Return type: List.

=cut

sub mounted_filesystems {

    # set and check variables
    my ( $self, @mounted ) = (shift);

    # get all mounted data
    $self->process_fs_mount_file() if not $self->_fs_mounts();

    # return list of mounted filesystems
    for my $mount_data ( $self->_fs_mounts() ) {
        my $fs = @$mount_data[0];
        push @mounted, $fs;
    }
    @mounted;
}

=head3 filesystem_mountpoint()

Determine mount point of filesystem.

Will run 'process_fs_mount_file' if this has not already occurred. Note that this method will be invoked without an argument so it will use the default mount file. If your script needs to use a different mount file, make sure to run 'process_fs_mount_file' explicitly before calling 'get_mounted_filesystems'.

This method is based on an assumption that the mount file has at least one entry in it. On modern Linux systems that will always be true.

Credit: based on Linux::Mounts perl module by Stephane Chmielewski <snck@free.fr>.

Parameters: [ 0 = class ] , 1 = device node.

Return type: Scalar (path).

=cut

sub filesystem_mountpoint {

    # set and check variables
    my ( $self, $fs, $mnt ) = ( shift, shift );
    $fs = $self->drive_selected() if not $fs;
    die "Invalid filesystem '$fs'. Stopping" if not -e $fs;
    $fs = $self->true_path($fs);

    # get all mounted data
    $self->process_fs_mount_file() if not $self->_fs_mounts();

    # get mountpoint
    for my $mount_data ( $self->_fs_mounts() ) {

        # retrieve filesystem (device node path) and mount point
        my ( $dev_fs, $dev_mnt ) = @$mount_data[ 0, 1 ];
        if ( $dev_fs eq $fs ) {
            $mnt = $dev_mnt;
            last;
        }
    }
    $mnt;
}

=head3 pid_running()

Determines whether process id is running.

A snapshot of the process list is captured into a table when this method is called for the first time. Any further invocations of this method then access the same table. To refresh the process table the method 'reload_processes' must be called.

Parameters: [ 0 = class ] , 1 = pid.

Return type: Scalar (boolean). (note: return value is actually the number of matching processes -- this is effectively a boolean value)

=cut

sub pid_running {

    # set and check variables
    my ( $self, $pid, $matches ) = ( shift, shift );
    my @pids = $self->pids();

    # search pids for matches
    $matches = grep {/^$pid$/} @pids;
    $matches;
}

=head3 process_running()

Determines whether process is running. Matches on process command. Can match against part or all of process commands.

A snapshot of the process list is captured into a table when this method is called for the first time. Any further invocations of this method then access the same table. To refresh the process table the method 'reload_processes' must be called.

Parameters: [ 0 = class ] , 1 = command , 2 = match_full_cmd (optional, default = FALSE).

Return type: Scalar (boolean). (note: return value is actually the number of matching processes -- this is effectively a boolean value)

=cut

sub process_running {

    # set and check variables
    my ( $self, $cmd, $matches, $full_match ) = ( shift, shift );
    $full_match = $self->boolise(shift) if $self->is_boolean( $_[0] );
    $full_match = $FALSE if not $full_match;
    my @cmds = $self->commands();

    # search process commands for matches
    if ($full_match) {
        $matches = grep {/^$cmd$/} @cmds;
    }
    else {
        $matches = grep {/$cmd/} @cmds;
    }
    $matches;
}

=head3 reload_processes()

Reloads/refreshes process table.

Parameters: [ 0 = class ].

Return type: N/A.

=cut

sub reload_processes { $_[0]->_load_processes(); }

=head3 file_mime_type()

Get mime type of file.

Uses module File::MimeInfo.

Note: This method previously used File::Type and its 'mime_type' method but that module incorrectly identifies some mp3 files as 'application/octet-stream'. If File::MimeInfo proves imperfect as well it may be necessary to use both. Other possible modules to use are File::MMagic and File::MMagic:Magic.

Parameters: [ 0 = class ] , 1 = file name.

Return type: Scalar, undef on failure.

=cut

sub file_mime_type { File::MimeInfo->new()->mimetype( $_[1] ); }

=head3 is_mp3()

Determine whether file is an mp3 file.

Note: This method previously used File::Type and its 'mime_type' method but that module incorrectly identifies some mp3 files as 'application/octet-stream'. If File::MimeInfo proves imperfect as well it may be necessary to use both. Other possible modules to use are File::MMagic and File::MMagic:Magic.

Parameters: [ 0 = class ] , 1 = file name.

Return type: Scalar, undef on failure.

=cut

sub is_mp3 {
    my ( $self, $file ) = ( shift, shift );
    return undef if not $file;
    return undef if not -f $file;
    return ( File::MimeInfo->new()->mimetype($file) eq 'audio/mpeg' )
        ? $TRUE
        : $FALSE;
}

=head3 is_mp4()

Determine whether file is an mp4 file.

Note: This method previously used File::Type and its 'mime_type' method but that module incorrectly identifies some mp3 files as 'application/octet-stream'. If File::MimeInfo proves imperfect as well it may be necessary to use both. Other possible modules to use are File::MMagic and File::MMagic:Magic.

Parameters: [ 0 = class ] , 1 = file name.

Return type: Scalar, undef on failure.

=cut

sub is_mp4 {
    my ( $self, $file ) = ( shift, shift );
    return undef if not $file;
    return undef if not -f $file;
    return ( File::MimeInfo->new()->mimetype($file) eq 'video/mp4' )
        ? $TRUE
        : $FALSE;
}

1;

__END__

=head1 NAME

Dn::CommonPerl - common methods for use by perl scripts

=head1 SYNOPSIS

    use Dn::Common;

=head1 DESCRIPTION

Provides methods used by Perl scripts. Can be used to create a standalone
object providing these methods; or as base class for derived module or class.

=head2 method config_params(parameter)

Uses Config::Simple.

=head3 Configuration files syntax

This method can handle configuration files with the following formats:

=over 4

=over

=item simple

    key1  value1
    key2  value2

=item http-like

    key1: value1
    key2: value2

=item ini file

    [block1]
    key1=value1
    key2=value2

    [block2]
    key3 = value3
    key4 = value4

Note in this case the block headings are optional.

=back

=back

The key is provided as the argument to method, e.g.:
    $parameter1 = $cp->config_param('key1');

If the ini file format is used with block headings, the block heading must be included using dot syntax, e.g.:
    $parameter1 = $cp->config_param('block1.key1');

=head3 Configuration file location and name

This method looks in these directories for configuration files in this order:
    ./               # i.e., bash $( pwd )
    /usr/local/etc
    /etc
    /etc/FOO         # where FOO is the calling script
    ~/               # i.e., bash $HOME

Each directory is searched for these file names in this order:
    FOOconfig     # where FOO is the calling script
    FOOconf
    FOO.config
    FOO.conf
    FOOrc
    .FOOrc

=head3 Multiple values

A key can have multiple values separated by commas:

    key1  value1, value2, "value 3"

or

    key1: value1, value2

or

    key1=value1, value2

This is different to multiple B<lines> in the configuration files defining the same key. In that case, the last such line overwrites all earlier ones.

=head3 Return value

As it is possible to retrieve multiple values for a single key, this method uses a list variable internally to capture parameter values. If the method is returning its result in a list context, the list is returned. If the method is returning its result in a scalar context, the list is interpolated, e.g., "@values".

=head1 DEPENDENCIES

These modules are not provided with Dn::Common.

=head2 File::Util

Used for various file and directory operations, including recursive directory
creation and extracting filename and/or dirpath from a filepath.

Debian: provided by package 'libfile-util-perl'.

=head2 File::Which

Used for finding paths to executable files.

Provides the 'which' function which mimics the bash 'which' utility.

Debian: provided by package 'libfile-which-perl'.

=head2 File::Basename

Parse file names.

Provides the 'fileparse' method.

Debian: provided by package 'perl'.

=head2 File::Copy

Used for file copying.

Provides the 'copy' and 'move' functions.

Debian: provided by package 'perl-modules'.

=head2 Cwd

Used to normalise paths, including following symlinks and collapsing relative
paths. Also used to provide current working directory.

Provides the 'abs_path' and 'getcwd' functions for these purposes,
respectively.

Debian: provided by package 'libfile-spec-perl'.

=head2 File::MimeInfo

Provides 'mimetype' method for getting mime-type information about mp3 files.

Debian: provided by package 'libfile-mimeinfo-perl'.

Note: Previously used File::Type and its 'mime_type' method to get file
mime-type information but that module incorrectly identifies some mp3 files as
'application/octet-stream'. Other alternatives are File::MMagic and
File::MMagic:Magic.

=head2 Date::Simple

Used for writing date strings.

Debian: provided by package 'libdate-simple-perl'.

=head2 Term::ANSIColor

Used for user input.

Provides the 'colored' function.

Debian: provided by package 'perl-modules'.

=head2 Term::Clui

Used for user input.

Provides 'choose', 'ask', 'edit' and 'confirm' functions.

To prevent responses being remembered between invocations, include this command
after the use statement:

    $ENV{'CLUI_DIR'} = "OFF"; # do not remember responses

Debian: provided by package 'libperl-term-clui'.

=head2 Text::Wrap

Used for formatting text into readable paragraphs.

Provides the 'wrap' function.

Debian: provided by package 'perl-base'.

=head2 Storable

Used for storing and retrieving persistent data.

Provides the 'store' and 'retrieve' functions.

Debian: provided by package 'perl'.

=cut

use Storable;

=head2 Config::Simple

Reads and parses configuration files.

Provides the 'import_from' function.

Debian: provided by package 'libconfig-simple-perl'.

=head2 Term::ReadKey

Used for reading single characters from keyboard.

Provides the ReadMode' and 'ReadKey' functions.

Debian: provided by package 'libterm-readkey-perl'.

=head2 Net::Ping::External

Cross-platform interface to ICMP "ping" utilities. Enables the pinging of
internet hosts.

Provides the 'ping' function.

Debian: provided by package 'libnet-ping-external-perl'.

=head2 Gtk2::Notify

Provides access to libnotify.

Provides the 'set_timeout' and 'show' functions.

The module man page recommends the following nonstandard invocation:

    use Gtk2::Notify -init, "$0";

Debian: provided by package 'libgtk2-notify-perl'.

=head2 Proc::ProcessTable

Provides access to system process table, i.e., output of 'ps'.

Provides the 'table' method.

Debian: provided by package 'libproc-processtable-perl'.

=head2 Logger::Syslog

Interface to system log.

Provides functions 'debug', 'notice', 'warning' and 'error'.

Some system logs only record some message types. On debian systems, for
example, /var/log/messages records only 'notice' and 'warning' message types
while /var/log/syslog records all message types.

Debian: provided by package 'liblogger-syslog-perl'.

=head2 Dn::Menu

Provides menus for use by Perl scripts. There are three kinds of menus
available: hotkey, terminal-based and graphical.

Debian: provided by package 'libdnmenu-perl'.

=head2 Desktop::Detect

Detects running desktop.

Must export method 'detect_desktop'.


=head2 dncommon-vars bash library

Common variables used by bash and perl scripts.

Debian: provided by package 'libdncommon-vars'.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 COPYRIGHT

Copyright 2015- David Nebauer

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
