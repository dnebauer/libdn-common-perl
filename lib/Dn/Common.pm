package Dn::Common;

use Mouse;
use 5.014_002;
use version; our $VERSION = qv('1.0.5');

# use of Gtk2::Notify causes debuild to fail with error:
#   perl Build test --verbose 1
#   Gtk-WARNING **: cannot open display:  \
#       at /usr/lib/x86_64-linux-gnu/perl5/5.20/Gtk2.pm line 126
# Test::NeedsDisplay prevents that error by loading a fake display
# Test::NeedsDisplay needs to be loaded early -- according to the
#   manpage, "it should be loaded as early as possible, before
#   anything has a chance to change script parameters. These params
#   will be resent through to the script again."
use Test::NeedsDisplay;

use namespace::autoclean;
use Mouse::Util::TypeConstraints;
use MouseX::NativeTraits;
use Function::Parameters;
use Carp qw(cluck croak);
use Env qw(CLUI_DIR HOME PWD);
use Readonly;
use autodie qw(open close);
use English qw(-no_match_vars);
use Data::Dumper::Simple;

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;

# DEPENDENCIES

use Config::Simple;
use Cwd qw(abs_path getcwd);
use Date::Simple;
use Desktop::Detect qw(detect_desktop);
use File::Basename;
use File::Copy;
use File::MimeInfo;
use File::Util;
use File::Which;
use Gtk2::Notify -init, "$PROGRAM_NAME";
use HTML::Entities;
use Logger::Syslog;
use Net::DBus;
use Net::Ping::External qw(ping);
use Proc::ProcessTable;
use Storable;
use Term::ANSIColor;
use Term::Clui;
$CLUI_DIR = 'OFF';    # do not remember responses
use Term::ReadKey;
use Text::Wrap;
use Time::Simple;

use experimental 'switch';

# ATTRIBUTES

# subtype: filepath
subtype 'FilePath' => as 'Str' => where { -f abs_path($_) } =>
    message {"Invalid file '$_'"};

# attribute: script
#            public, scalar
#            basename of calling script
has '_script' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { File::Util->new()->strip_path($PROGRAM_NAME); },
);

# attribute: kde_running
#            public, boolean
#            whether kde is running
has 'kde_running' => (
    is      => 'ro',
    isa     => 'Bool',
    default => sub {
        ( Desktop::Detect->detect_desktop()->{desktop} eq 'kde-plasma' )
            ? $TRUE
            : $FALSE;
    },
);

# attribute: _screensaver
#           private, Net::DBus::RemoteObject object
#           used in suspending and restoring screensaver
has '_screensaver' => (
    is      => 'rw',
    isa     => 'Net::DBus::RemoteObject',
    default => sub {
        Net::DBus->session->get_service('org.freedesktop.ScreenSaver')
            ->get_object('/org/freedesktop/ScreenSaver');
    },
);

# attribute: _screensaver_cookie
#            private, scalar integer
#            cookie tracking inhibit (suspend) requests
has '_screensaver_cookie' => (
    is  => 'rw',
    isa => 'Int',
);

# attribute: _screensaver_attempt_suspend
#            private, boolean
#            whether there is a kde screensaver to suspend
has '_screensaver_attempt_suspend' => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub {
        ( Desktop::Detect->detect_desktop()->{desktop} eq 'kde-plasma' )
            ? $TRUE
            : $FALSE;
    },
);

# attribute: _configuration_files
#            private, array of Config::Simple objects
#            configuration files to search
has '_configuration_files' => (
    is      => 'rw',
    isa     => 'ArrayRef[Config::Simple]',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        _config_files           => 'elements',
        _add_config_file        => 'push',       # ($obj) -> void
        _processed_config_files => 'count',      # () -> $boolean
    },
    documentation => 'hold configuration file objects',
);

# attribute: _processes
#            private, procsses
has '_processes' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Str]',
    lazy    => $TRUE,
    builder => sub { {} },
    handles => {
        _add_process         => 'set',       # ($pid, $cmd)->void
        _command             => 'get',       # ($pid)->$cmd
        _clear_processes     => 'clear',     # ()->void
        _pids                => 'keys',      # ()->@pids
        _commands            => 'values',    # ()->@commands
        _processes_pair_list => 'kv',        # ()->([$pid,$cmd],...)
        _has_processes       => 'count',     # ()->$boolean
    },
);

# attribute: _icon_error
#            private, FilePath subtype
#            error icon
has '_icon_error' => (
    is      => 'rw',
    isa     => 'FilePath',
    lazy    => $TRUE,
    builder => '_build_icon_error',
);

method _build_icon_error () {
    return $self->_get_icon('error.xpm');
}

# attribute: _icon_warn
#            private, FilePath subtype
#            warn icon
has '_icon_warn' => (
    is      => 'rw',
    isa     => 'FilePath',
    lazy    => $TRUE,
    builder => '_build_icon_warn',
);

method _build_icon_warn () {
    return $self->_get_icon('warn.xpm');
}

# attribute: _icon_question
#            private, FilePath subtype
#            question icon
has '_icon_question' => (
    is      => 'rw',
    isa     => 'FilePath',
    lazy    => $TRUE,
    builder => '_build_icon_question',
);

method _build_icon_question () {
    return $self->_get_icon('question.xpm');
}

# attribute: _icon_info
#            private, FilePath subtype
#            info icon
has '_icon_info' => (
    is      => 'rw',
    isa     => 'FilePath',
    lazy    => $TRUE,
    builder => '_build_icon_info',
);

method _build_icon_info () {
    return $self->_get_icon('info.xpm');
}

# attribute: _urls
#            private, array of strings
#            urls to ping
has '_urls' => (
    is            => 'rw',
    isa           => 'ArrayRef[Str]',
    traits        => ['Array'],
    builder       => '_build_urls',
    handles       => { _ping_urls => 'elements', },
    documentation => 'urls to ping',
);

method _build_urls () {
    return [ 'www.debian.org', 'www.uq.edu.au' ];
}

=begin comment

STYLE NOTES

eval
   
- [http://www.perlmonks.org/?node_id=736082]
-
- use form:
-
-     if ( !eval { CODE_BLOCK; 1 } ) {
-         # handle error
-     }
-     # handle success
-
- where code block can be a variable assignment

=end comment

=cut

# METHODS

# method: _get_icon($icon)
#
# does:   gets filepath of icon included in module package
# params: $icon - file name of icon [required]
# prints: nil
# return: icon filepath
method _get_icon ($icon) {
    if ( not $icon ) {
        return;
    }
    my $branch = "auto/share/dist/Dn-Common/$icon";
    for my $root (@INC) {
        if ( -e "$root/$branch" ) {
            return "$root/$branch";
        }
    }
    return;
}

# method: _process_config_files()
#
# does:   find all configuration files for calling script
#         loads attribute '_configuration_files'
# params: nil
# prints: nil
# return: nil
method _process_config_files () {
    my $root = File::Util->new()->strip_path($PROGRAM_NAME);

    # set directory and filename possibilities to try
    my ( @dirs, @files );
    push @dirs,  $PWD;                # ./     == bash $( pwd )
    push @dirs,  '/usr/local/etc';    # /usr/local/etc/
    push @dirs,  '/etc';              # /etc/
    push @dirs,  "/etc/$root";        # /etc/FOO/
    push @dirs,  $HOME;               # ~/     == bash $HOME
    push @files, "${root}config";     # FOOconfig
    push @files, "${root}conf";       # FOOconf
    push @files, "${root}.config";    # FOO.config
    push @files, "${root}.conf";      # FOO.conf
    push @files, "${root}rc";         # FOOrc
    push @files, ".${root}rc";        # .FOOrc

    # look for existing combinations and capture those config files
    for my $dir (@dirs) {
        for my $file (@files) {
            my $cf = sprintf '%s/%s', $dir, $file;
            if ( -r "$cf" ) {
                $self->_add_config_file( Config::Simple->new($cf) );
            }
        }
    }
}

# method: config_param($param)
#
# does:   get parameter value
# params: $param - configuration parameter name
# prints: nil
# return: list of parameter value(s)
# uses:   Config::Simple
method config_param ($param) {

    # set and check variables
    if ( not $param ) {
        return;
    }
    my @values;

    # read config files if not already done
    if ( not $self->_processed_config_files ) {
        $self->_process_config_files;
    }

    # cycle through config files looking for matches
    # - later matches override earlier matches
    # - force list context initially
    for my $config_file ( $self->_config_files ) {
        if ( $config_file->param($param) ) {
            @values = $config_file->param($param);
        }
    }

    # return value depends on calling context
    return @values;
}

# method: _load_processes()
#
# does:   load '_processes' attribute with pid=>command pairs
# params: nil
# prints: nil
# return: nil
method _load_processes () {
    $self->_clear_processes;
    foreach my $process ( @{ Proc::ProcessTable->new()->table() } ) {
        $self->_add_process( $process->pid, $process->cmndline );
    }
}

# method: _reload_processes()
#
# does:   reload '_processes' attribute with pid=>command pairs
# params: nil
# prints: nil
# return: nil
method _reload_processes () {
    $self->_load_processes;
}

# method: suspend_screensaver([$title], [$msg])
#
# does:   suspends kde screensaver if present
# params: $title - title of message box [optional, default=scriptname]
#         $msg   - message explaining suspend request
#                 [named param, optional, default='request from $PID']
#                 example: 'running smplayer'
# prints: nil (feedback via popup notification)
# return: boolean
# uses:   Net::DBus::RemoteObject
#         DBus service org.freedesktop.ScreenSaver
method suspend_screensaver ($title, :$msg) {
    if ( not $title ) { $title = $self->_script; }
    if ( not $msg )   { $msg   = "request from $PID"; }
    my $cookie;

    # sanity checks
    my $err;
    if ( $self->_screensaver_cookie ) {      # do not repeat request
        $err = 'This process has already requested screensaver suspension';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }
    if ( not $self->_screensaver_attempt_suspend ) {    # must be kde
        $err = 'Cannot suspend screensaver on non-KDE desktop';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }

    # suspension screensaver
    if ( !eval { $cookie = $self->_screensaver->Inhibit( $PID, $msg ); 1 } ) {
        $err = 'Failed to suspend screensaver';         # failed
        $self->notify_sys( $err, type => 'error', title => $title );
        $err = "Error: $EVAL_ERROR";
        $self->notify_sys( $err, type => 'error', title => $title );
        $self->_screensaver_attempt_suspend($FALSE);
        return;
    }
    else {                                              # succeeded
        $self->notify_sys( 'Suspended screensaver', title => $title );
        $self->_screensaver_cookie($cookie);
        return $TRUE;
    }
}

# method: restore_screensaver([$title])
#
# does:   restores suspended kde screensaver
# params: $title - title of message box [optional, default=scriptname]
# prints: nil (feedback via popup notification)
# return: boolean
# uses:   Net::DBus::RemoteObject
#         DBus service org.freedesktop.ScreenSaver
method restore_screensaver ($title) {
    if ( not $title ) { $title = $self->_script; }
    my $cookie;

    # sanity checks
    my $err;
    if ( $self->_screensaver_cookie ) {
        $cookie = $self->_screensaver_cookie;
    }
    else {                            # must first be suspended
        $err = 'Screensaver has not been suspended by this process';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }
    if ( not $self->_screensaver_attempt_suspend ) {    # must be kde
        $err = 'Cannot suspend screensaver on non-KDE desktop';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }

    # restore screensaver
    if ( !eval { $self->_screensaver->UnInhibit($cookie); 1 } ) {    # failed
        $err = 'Unable to restore screensaver programmatically';
        $self->notify_sys( $err, type => 'error', title => $title );
        $err = "Error: $EVAL_ERROR";
        $self->notify_sys( $err, type => 'error', title => $title );
        $err = 'It should restore automatically as this script exits';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }
    else {    # succeeded
        $self->notify_sys( 'Restored screensaver', title => $title );
        $self->_screensaver_cookie();
        return $TRUE;
    }
}

# method: notify_sys($msg, [$title], [$type], [$icon], [$time])
#
# does:   display message to user in system notification area
# params: $msg   - message content [required]
#         $title - message title [optional, default=calling script name]
#         $type  - 'info'|'question'|'warn'|'error'
#                 [optional, default='info']
#         $icon  - message icon filepath [optional, no default]
#         $time  - message display time (msec) [optional, default=10,000]
# return: boolean, whether able to display notification
# usage:  $cp->notify_sys('Operation successful!', title => 'Outcome');
# alert:  do not call this method from a spawned child process --
#         the 'show()' call in the last line of this method causes
#         the child process to hang without any feedback to user
# note:   not guaranteed to respect newlines
# uses:   Gtk2::Notify
#         Test::NeedsDisplay (required to prevent build tools from failing)
# TODO:   implement changed interface
method notify_sys ($msg, :$title, :$type, :$icon, :$time) {

    # parameters
    # - msg
    return if not($msg);

    # - title
    if ( not $title ) { $title = $self->_script }

    # - type
    my %is_valid_type = map { ( $_ => 1 ) } qw/info question warn error/;
    if ( not( $type and $is_valid_type{$type} ) ) {
        confess "Invalid type '$type'";
    }

    # - icon
    if ( not( $icon and -e $icon ) ) {
        for ($type) {    # no default because type *must* be 1 of these 4
            when (/^info$/xsm)     { $icon = $self->_icon_info }
            when (/^question$/xsm) { $icon = $self->_icon_question }
            when (/^warn$/xsm)     { $icon = $self->_icon_warn }
            when (/^error$/xsm)    { $icon = $self->_icon_error }
            default { confess "Invalid type '$type'" }
        }
    }

    # - time
    if ( not( $time and $time =~ /^[1-9]\d+\z/xsm ) ) {
        $time = 10_000;
    }

    # display notification popup
    my $n = Gtk2::Notify->new( $title, $msg, $icon );
    $n->set_timeout($time);
    $n->show();
    return;
}

# method: logger($message, $type)
#
# does:   write message to system logs
# params: $message - message content [required]
#         $type    - message type ['debug'|'notice'|'warning'|'error']
#                   [optional, default='notice']
# prints: nil
# return: nil
# note:   not all message types appear in all system logs -- on debian,
#         for example, /var/log/messages records only notice and warning
#         log messages while /var/log/syslog records all log messages
# uses:   Logger::Syslog
method logger ($message, $type = 'notice') {

    # set and check variables
    return if not $message;
    $type =~ s/(.*)/\L$1/gxsm;               # lowercase

    # log message
    for ($type) {
        when (/^debug$/xsm)   { Logger::Syslog::debug($message) }
        when (/^notice$/xsm)  { Logger::Syslog::notice($message) }
        when (/^warning$/xsm) { Logger::Syslog::warning($message) }
        when (/^error$/xsm)   { Logger::Syslog::error($message) }
        default               { confess "Invalid type '$type'" }
    }

    return;
}

# method: extract_key_value($key, @items)
#
# does:   extract key value from list
#         assumes key and value are pair of elements in list
#         also returns list with key and value removed
# params: $key   - key, first element in key-value pair
#         @items - items to analyse
# prints: nil
# return: list ($key_value, @amended_list)
# usage:  my ($value, @list) = $cp->($key, @list);
method extract_key_value ($key, @items) {
    my ( @remainder, $value, $next_is_value );
    for my $item (@items) {
        if ( lc $item eq lc $key ) {      # key value next
            $next_is_value = $TRUE;
        }
        elsif ($next_is_value) {          # this is prepend value
            $value         = $item;
            $next_is_value = $FALSE;
        }
        else {                            # a message item
            push @remainder, $item;
        }
    }
    return ( $value, @remainder );
}

# method: notify(@messages, [$prepend])
#
# does:   display console message
# params: @messages - message lines [required]
#         $prepend  - whether to prepend script name to message lines
#                     named parameter, boolean, optional, default=false
# prints: messages
# return: nil
# usage:  $cp->notify('File path is:', $filepath);
#         $cp->notify('File path is:', $filepath, prepend => $TRUE);
# note:   respects newline if enclosed in double quotes
# TODO:   implement changed interface
method notify (@messages) {

    # set prepend flag and display messages
    my ( $prepend, @messages )
        = $self->extract_key_value( 'prepend', @messages );

    # set prefix
    my $prefix = ($prepend) ? $self->_script . ': ' : q{};

    # display messages
    for my $message (@messages) {
        say "$prefix$message";
    }
}

# method: abort(@messages, [$prepend])
#
# does:   abort script with error message
# params: @messages - message lines [required]
#         $prepend  - whether to prepend script name to message lines
#                     [named parameter, boolean, optional, default=false]
# prints: messages
# return: nil
# usage:  $cp->abort('Did not work', $filepath);
#         $cp->abort('Did not work', $filepath, prepend => $TRUE);
# note:   respects newline if enclosed in double quotes
# TODO:   implement changed interface
method abort (@messages) {

    # display messages
    $self->notify(@messages);

    # set prefix
    my ( $prepend, @messages )
        = $self->extract_key_value( 'prepend', @messages );
    my $prefix = ($prepend) ? $self->_script . ': ' : q{};

    # abort
    die "${prefix}Aborting\n";
}

# method: clear_screen()
#
# does:   clear the terminal screen
# params: nil
# prints: nil
# return: nil
# TODO:   implement changed interface
method clear_screen () {
    system 'clear';
}

# method: input_choose($prompt, @options, [$prepend])
#
# does:   user selects option from a menu
# params: $prompt  - menu prompt [required]
#         @options - menu options [required]
#         $prepend - flag to prepend script name to prompt
#                    [named parameter, boolean, optional, default=false]
# prints: menu and user interaction
# usage:  my $value = undef;
#         my @options = ( 'Pick me', 'No, me!' );
#          while ($TRUE) {
#              @picks = $self->input_choose(
#                  "Select value:", @options, $prepend => 1
#              );
#              last if @picks;
#              say "Invalid choice. Sorry, please try again.";
#          }
# return: return value depends on the calling context:
#         - scalar: returns scalar (undef if choice cancelled)
#         - list:   returns list (empty list if choice cancelled)
# uses:   Term::Clui
# TODO:   implement changed interface
method input_choose ($prompt, @options) {
    return if not @options;
    ( my $prepend, @options )
        = $self->extract_key_value( 'prepend', @options );
    if ($prepend) {
        $prompt = $self->_script . ': ' . $prompt;
    }
    Term::Clui::choose( $prompt, @options );
}

# method: input_ask($prompt, [$default],[$prepend])
#
# does:   get input from user
# params: $prompt  - user prompt [required]
#         $default - default input [optional, default=q{}]
#         $prepend - whether to prepend scrip name to prompt
#                    [named parameter, options, default=false]
# prints: user interaction
# return: user input (scalar)
# note:   intended for entering short values
#         -- once the line wraps the user cannot move to previous line
#         use method 'input_large' for long input
# uses:   Term::Clui
# TODO:   implement changed interface
method input_ask ($prompt, $default, @options) {
    return if not $prompt;
    ( my $prepend, @options )
        = $self->extract_key_value( 'prepend', @options );
    if ($prepend) {
        $prompt = $self->_script . ': ' . $prompt;
    }
    Term::Clui::ask( $prompt, $default );
}

# method: input_large($prompt, [$default],[$prepend])
#
# does:   get input from user
# params: $prompt  - user prompt [required]
#         $default - default input [optional, default=q{}]
#         $prepend - whether to prepend scrip name to prompt
#                    [named parameter, options, default=false]
# prints: user interaction
# return: user input (list, split on newlines)
# note:   intended for entering lathe, multi-line values
#         for short values, where prompt and response will easily fit
#           on one line, use method'input_ask'
# uses:   Term::Clui
# TODO:   implement changed interface
method input_large ($prompt, $default, @options) {

    # set variables
    return if not $prompt;
    ( my $prepend, @options )
        = $self->extract_key_value( 'prepend', @options );
    if ($prepend) {
        $prompt = $self->_script . ': ' . $prompt;
    }
    my $rule = q{-} x 60;
    my $content
        = "[Everything to first horizontal rule will be deleted]\n"
        . $prompt . "\n"
        . $rule . "\n"
        . $default;

    # get user input
    # - put into list splitting on newline
    my @data = split /\n/xsm, Term::Clui::edit( $prompt, $content );

    # get index of horizontal rule
    # - first line if no horizontal rule
    my ( $index, $rule_index ) = ( 1, 0 );
    foreach my $line (@data) {
        chomp $line;
        if ( $line =~ /^-+$/xsm ) {
            $rule_index = $index;
        }
        $index++;
    }

    # return user input lines following horizontal rule
    if (@data) {
        return join "\n", @data[ $rule_index .. $#data ];
    }
    return;
}

# method: input_confirm($question, [$prepend])
#
# does:   user answers y/n to a question
# params: $question - question to be answered with yes or no
#                     [required, can be multi-line (use "\n")]
#         $prepend  - whether to prepend scrip name to question
#                     [named parameter, options, default=false]
# prints: user interaction
#         after user answers, all but first line of question
#           is removed from the screen
#         answer also remains on screen
# return: scalar boolean
# usage:  my $prompt = "Short question?\n\nMore\nmulti-line\ntext.";
#         if ( input_confirm($prompt) ) {
#             # do stuff
#         }
# uses:   Term::Clui
# TODO:   implement changed interface
method input_confirm ($question, @options) {

    # set variables
    return if not $question;
    ( my $prepend, @options )
        = $self->extract_key_value( 'prepend', @options );
    if ($prepend) {
        $question = $self->_script . ': ' . $question;
    }

    # get user response
    Term::Clui::confirm($question);
}

# method: display($string)
#
# does:   displays screen text with word wrapping
# params: $string - text to display [required]
# prints: text for display
# return: nil
# usage:  $cp->display($long_string);
# uses:   Text::Wrap
method display ($string) {
    say Text::Wrap::wrap( q{}, q{}, $string );
}

# method: vim_print($type, @messages)
#
# does:   print text to terminal screen using vim's default colour scheme
# params: $type     - type ['title'|'error'|'warning'|'prompt'|'normal']
#                     case-insensitive, can supply partial value
#                     [required]
#         @messages - content to print [required, multi-part]
#                     can contain escaped double quotes
# prints: messages
# return: nil
# detail: five styles have been implemented:
#                  Vim
#                  Highlight
#         Style    Group       Foreground    Background
#         -------  ----------  ------------  ----------
#         title    Title       bold magenta  normal
#         error    ErrorMsg    bold white    red
#         warning  WarningMsg  red           normal
#         prompt   MoreMsg     bold green    normal
#         normal   Normal      normal        normal
# usage:  $cp->vim_print( 't', "This is a title" );
# note:   will gracefully handle arrays and array references in message list
# uses:   Term::ANSIColor
# TODO:   implement changed interface
method vim_print ($type, @messages) {

    # variables
    # - messages
    @messages = $self->listify(@messages);

    # - type
    if ( not $type ) { $type = 'normal'; }

    # - attributes (to pass to function 'colored')
    my $attributes;
    for ($type) {
        when (/^t/ixsm) { $attributes = [ 'bold', 'magenta' ] }
        when (/^p/ixsm) { $attributes = [ 'bold', 'bright_green' ] }
        when (/^w/ixsm) { $attributes = ['bright_red'] }
        when (/^e/ixsm) { $attributes = [ 'bold', 'white', 'on_red' ] }
        default { $attributes = ['reset'] }
    }

    # print messages
    for my $message (@messages) {
        say Term::ANSIColor::colored( $attributes, $message );
    }
}

# method: vim_printify($type, $message)
#
# does:   modifies a single string to be passed to 'vim_list_print'
# params: $type    - as per method 'vim_print' [required]
#         $message - content to be modified [required]
#                    can contain escaped double quotes
# prints: nil
# return: modified string
# usage:  @output = $cp->vim_printify( 't', 'My Title' );
# detail: the string is given a prefix that signals to 'vim_list_print'
#         what format to use (prefix is stripped before printing)
# TODO:   implement changed interface
method vim_printify ($type, $message) {

    # variables
    # - message
    if ( not $message ) { return q{}; }

    # - type
    if ( not $type ) { $type = 'normal'; }

    # - token to prepend to message
    my $token;
    for ($type) {
        when (/^t/ixsm) { $token = '::title::' }
        when (/^p/ixsm) { $token = '::prompt::' }
        when (/^w/ixsm) { $token = '::warn::' }
        when (/^e/ixsm) { $token = '::error::' }
        default         { $token = q{} }
    }

    # return altered string
    return "$token$message";
}

# method: vim_list_print(@messages)
#
# does:   prints a list of strings to the terminal screen using
#         vim's default colour scheme
# detail: see method 'vim_print' for details of the colour schemes
#         each message can be printed in a different style
#         - element strings need to be prepared using 'vim_printify'
# params: @messages - messages to display [required]
#                     can contain escaped double quotes.
# prints: messages in requested styles
# return: nil
method vim_list_print (@messages) {
    my @messages = $self->listify(@messages);
    my ( $index, $flag );
    foreach my $message (@messages) {
        for ($message) {
            when (/^::title::/ixsm)  { $index = 9;  $flag = 't' }
            when (/^::error::/ixsm)  { $index = 9;  $flag = 'e' }
            when (/^::warn::/ixsm)   { $index = 8;  $flag = 'w' }
            when (/^::prompt::/ixsm) { $index = 10; $flag = 'p' }
            default                  { $index = 0;  $flag = 'n' }
        }
        $self->vim_print( $flag, substr( $message, $index ) );
    }
}

# method: listify(@items)
#
# does:   tries to convert scalar, array and hash references to scalars
# params: @items - items to convert to lists [required]
# prints: warnings for other reference types
# return: list
method listify (@items) {
    my ( @scalars, $scalar, @array, %hash );
    for my $item (@items) {
        my $ref = ref $item;
        if ($ref) {
            for ($ref) {
                when (/SCALAR/xsm) {
                    $scalar = ${$item};
                    push @scalars, $self->listify($scalar);
                }
                when (/ARRAY/xsm) {
                    @array = @{$item};
                    foreach my $element (@array) {
                        push @scalars, $self->listify($element);
                    }
                }
                when (/HASH/xsm) {
                    %hash = %{$item};
                    foreach my $key ( keys %hash ) {
                        push @scalars, $self->listify($key);
                        push @scalars, $self->listify( $hash{$key} );
                    }
                }
                default {
                    cluck "Cannot listify a '$ref'";
                    say 'Item dump:';
                    say q{-} x 30;
                    cluck Dumper($item);
                    say q{-} x 30;
                }
            }
        }
        else {
            push @scalars, $item;
        }
    }
    if ( not @scalars ) { return; }
    return @scalars;
}

# method: browse($title, $text)
#
# does:   displays a large volume of text in default editor
# params: $title - title applied to editor temporary file
# prints: nil
# return: nil
method browse ($title, $text) {
    return if not $title;
    return if not $text;
    my $text
        = qq{\n}
        . $title
        . qq{\n\n}
        . qq{[This text should be displaying in your default editor.\n}
        . qq{If no default editor is specified, vi(m) is used.\n}
        . q{To exit this screen, exit the editor as you normally would}
        . q{ - 'ZQ' for vi(m).]}
        . qq{\n\n}
        . $text;
    Term::Clui::edit( $title, $text );
}

# method: prompt([message])
#
# does:   display message and prompt user to press any key
# params: message - prompt message [optional]
#                   [default='Press any key to continue']
# prints: prompt message
# return: nil
method prompt ($message) {
    if ( not $message ) { $message = 'Press any key to continue... '; }
    print $message;
    Term::ReadKey::ReadMode('raw');
    while ($TRUE) {
        my $key = Term::ReadKey::ReadKey(0);
        last if defined $key;
    }
    Term::ReadKey::ReadMode('restore');
    print "\n";
}

# method: get_path($filepath)
#
# does:   get path from filepath.
# params: $filepath - file path [required]
# prints: nil
# return: scalar path
# uses:   File::Util
method get_path ($filepath) {
    if ( not $filepath ) { confess 'No file path provided'; }
    my $path = File::Util->new()->return_path($filepath);
    if ( $path eq $filepath ) {
        $path = q{};
    }
    return $path;
}

# method: executable_path($exe)
#
# does:   find path to executable
# params: $exe - short name of executable [requiered]
# prints: nil
# return: scalar filepath
#         scalar boolean (undef if not found)
# uses:   File::Which
method executable_path ($exe) {
    if ( not $exe ) { confess 'No executable name provided'; }
    scalar File::Which::which($exe);
}

# method: make_dir($dir_path)
#
# does:   make directory recursively
# params: $dir_path - directory path [required]
# prints: nil
# return: boolean (whether created)
# note:   if directory already exists does nothing but return true
# uses:   File::Util
method make_dir ($dir_path) {
    if ( not $dir_path ) { confess 'No directory path provided'; }
    File::Util->new()->make_dir( $dir_path, { if_not_exists => $TRUE } )
        or confess "Unable to create '$dir_path'";
}

# method: files_list([$dir_path])
#
# does:   list files in directory
# params: $directory - directory path [optional, default=cwd]
# prints: nil
# return: list, die if operation fails
method files_list ($dir) {
    if ( not $dir ) { $dir = $self->cwd(); }
    $dir = $self->true_path($dir);
    if ( not -d $dir ) { confess "Invalid directory '$dir'"; }
    my $f = File::Util->new();
    my @files = $f->list_dir( $dir, { files_only => $TRUE } )
        or confess "Unable to get file listing from '$dir'";
    return @files;
}

# method: dirs_list($directory)
#
# does:   list subdirectories in directory
# params: $directory - directory path [optional, default=cwd]
# prints: nil
# return: list, die if operation fails
method dirs_list ($dir) {
    if ( not $dir ) { $dir = $self->cwd(); }
    $dir = $self->true_path($dir);
    if ( not -d $dir ) { confess "Invalid directory '$dir'"; }
    my $f = File::Util->new();
    my @dirs = $f->list_dir( $dir, { dirs_only => $TRUE } )
        or croak "Unable to get directory listing from '$dir'";
    @dirs = grep { !/^[.]{1,2}$/xsm } @dirs;    # exclude '.' and '..'
    return @dirs;
}

# method: backup_file($file)
#
# does:   backs up file by renaming it to a unique file name
# params: $file - file to back up [required]
# prints: nil (error message if fails)
# return: nil (die if fails)
# detail: simply adds integer to file basename to get unique file name
# uses:   File::Copy (move), File::Basename (fileparse)
method backup_file ($file) {

    # determine backup file name
    my ( $base, $suffix )
        = ( File::Basename::fileparse( $file, qr/[.][^.]*\z/xsm ) )[ 0, 2 ];
    my $count  = 1;
    my $backup = $base . q{_} . $count++ . $suffix;
    while ( -e $backup ) {
        $backup = $base . q{_} . $count++ . $suffix;
    }

    # do backup
    File::Copy::move( $file, $backup )
        or confess "Error: unable to backup $base to $backup";

    # notify user
    say "Existing file '$file' renamed to '$backup'";
}

# method: valid_positive_integer($value)
#
# does:   determine whether a valid positive integer (zero or above)
# params: $value - value to test [required]
# prints: nil
# return: boolean
method valid_positive_integer ($value) {
    if ( not defined $value ) { return; }
    for ($value) {
        when (/^[+]?0$/xsm)         { return $TRUE; }    # zero
        when (/^[+]?[1-9]\d*\z/xsm) { return $TRUE; }    # above zero
        default                     { return; }
    }
}

# method: valid_integer($value)
#
# does:   determine whether a valid integer (can be negative)
# params: $value - value to test [required]
# prints: nil
# return: boolean
method valid_integer ($value) {
    if ( not defined $value ) { return; }
    for ($value) {
        when (/^[+-]?0\z/xsm)        { return $TRUE; }    # zero
        when (/^[+-]?[1-9]\d*\z/xsm) { return $TRUE; }    # other int
        default                      { return; }
    }
}

# method: today()
#
# does:   get today as an ISO-formatted date
# params: nil
# prints: nil
# return: ISO-formatted date
# uses:   Date::Simple
method today () {
    return Date::Simple->today()->format('%Y-%m-%d');
}

# method: offset_date($offset)
#
# does:   get a date offset from today
# params: $offset - offset in days [required]
#                   can be positive or negative
# prints: nil
# return: ISO-formatted date (die if fails)
# uses:   Date::Simple
method offset_date ($offset) {
    if ( not( $offset and $self->valid_integer($offset) ) ) { return; }
    my $date = Date::Simple->today() + $offset;
    return $date->format('%Y-%m-%d');
}

# method: day_of_week([$date])
#
# does:   day of week the supplied date falls on
# params: $date - date in ISO format [optional, default=today]
# prints: nil
# return: scalar day
# uses:   Date::Simple
method day_of_week ($date) {
    if ( not $date ) { $date = $self->today(); }
    return if not $self->valid_date($date);
    my %day_numbers = (
        '0' => 'Sunday',
        '1' => 'Monday',
        '2' => 'Tuesday',
        '3' => 'Wednesday',
        '4' => 'Thursday',
        '5' => 'Friday',
        '6' => 'Saturday',
    );
    my $d          = Date::Simple->new($date);
    my $day_number = $d->day_of_week();
    my $day        = $day_numbers{$day_number};
    if ( not $day ) { return; }
    return $day;
}

# method: konsolekalendar_date_format($date)
#
# does:   get date formatted as konsolekalendar does in its output
#         example date value is 'Tues, 15 Apr 2008'
#         corresponding strftime format string is '%a, %e %b %Y'
# params: $date - ISO formatted date [optional, default=today]
# prints: nil
# return: scalar date string
method konsolekalendar_date_format ($date) {

    # get date
    if ( not $date ) { $date = $self->today(); }
    if ( not $self->valid_date($date) ) { return; }

    # reformat
    my $format = '%a, %e %b %Y';
    my $d      = Date::Simple->new($date)->format($format);
    $d =~ s/  / /gsm;                        # dates 1-9 have leading space
    return $d;
}

# method: valid_date($date)
#
# does:   determine whether date is valid and in ISO format
# params: $date - candidate date [required]
# prints: nil
# return: boolean
method valid_date ($date) {
    if ( not $date ) { return; }
    return Date::Simple->new($date);
}

# method: sequential_dates($date1, $date2)
#
# does:   determine whether supplied dates are in chronological sequence
# params: $date1 - first date, ISO-formatted [required]
#         $date1 - second date, ISO-formatted [required]
# prints: nil (error if invalid dates)
# return: boolean (die on failure)
method sequential_dates ($date1, $date2) {

    # check dates
    if ( not $date1 ) { confess 'Missing date'; }
    if ( not $date2 ) { confess 'Missing date'; }
    if ( not $self->valid_date($date1) ) {
        confess "Invalid date '$date1'";
    }
    if ( not $self->valid_date($date2) ) {
        confess "Invalid date '$date2'";
    }

    # compare dates
    my $d1 = Date::Simple->new($date1);
    my $d2 = Date::Simple->new($date2);
    return ( $d2 > $d1 );
}

# method: future_date($date)
#
# does:   determine whether supplied date occurs in the future,
#         i.e, today or after today
# params: $date - date to compare, must be ISO format [required]
# prints: nil (error if invalid date)
# return: boolean (dies if invalid date)
method future_date ($date) {

    # check date
    if ( not $self->valid_date($date) ) {
        confess "Invalid date '$date'";
    }

    # get dates
    my $iso_date = Date::Simple->new($date);
    my $today    = Date::Simple->new();

    # evaluate date sequence
    return ( $iso_date >= $today );
}

# method: valid_24h_time($time)
#
# does:   determine whether supplied time is valid 24 hour time
# params: $time - time to evaluate, 'HH::MM' format [required]
#                 leading zero can be dropped
# prints: nil
# return: boolean
# TODO: test eval
method valid_24h_time ($time) {
    if ( not $time ) { return; }
    if ( !eval { Time::Simple->new($time); 1 } ) {    # failed
        return;
    }
    return $TRUE;                                     # succeeded
}

# method: sequential_24h_times($time1, $time2)
#
# does:   determine whether supplied times are in chronological
#         sequential, i.e., second time occurs after first time
#         assume both times are from the same day
# params: $time1 - first time to compare, 24 hour time [required]
#         $time2 - second time to compare, 24 hour time [required]
# prints: nil (error if invalid time)
# return: boolean (dies if invalid time)
method sequential_24h_times ($time1, $time2) {

    # check times
    if ( not $self->valid_24h_time($time1) ) {
        confess "Invalid time '$time1'";
    }
    if ( not $self->valid_24h_time($time2) ) {
        confess "Invalid time '$time2'";
    }

    # compare
    my $t1 = Time::Simple->new($time1);
    my $t2 = Time::Simple->new($time2);
    return ( $t2 > $t1 );
}

# method: entitise($string)
#
# does:   convert reserved characters to HTML entities
# params: $string - string to analyse [required]
# prints: nil
# return: scalar string
# # uses: HTML::Entities
method entitise ($string = q//) {
    return HTML::Entities::encode_entities($string);
}

# method: deentitise($string)
#
# does:   convert HTML entities to reserved characters
# params: $string - string to analyse [required]
# prints: nil
# return: scalar string
# # uses: HTML::Entities
method deentitise ($string = q//) {
    return HTML::Entities::decode_entities($string);
}

# method: tabify($string, [$tab_size])
#
# does:   covert tab markers ('\t') to spaces
# params: $string   - string to convert [required]
#         $tab_size - size of tab in characters [optional, default=4]
# prints: nil
# return: scalar string
method tabify ($string = q//, $tab_size = 4) {

    # set tab
    if ( $tab_size !~ /^[1-9]\d*\z/xsm ) { $tab_size = 4; }
    my $tab = q{ } x $tab_size;

    # convert tabs
    $string =~ s/\\t/$tab/gxsm;
    return $string;
}

# method: trim($string)
#
# does:   remove leading and trailing whitespace
# params: $string - string to be converted [required]
# prints: nil
# return: scalar string
method trim ($string = q//) {
    $string =~ s/^\s+//xsm;
    $string =~ s/\s+\z//xsm;
    return $string;
}

# method: boolise($value)
#
# does:   convert value to boolean
# detail: convert 'yes', 'true' and 'on' to 1
#         convert 'no, 'false, and 'off' to 0
#         other values returned unchanged
# params: $value - value to analyse [required]
# prints: nil
# return: boolean
method boolise ($value) {
    if ( not defined $value ) { return; }    # handle special case
    for ($value) {
        when (/^yes$|^true$|^on$/ixsm)  { return 1; }        # true -> 1
        when (/^no$|^false$|^off$/ixsm) { return 0; }        # false -> 0
        default                         { return $value; }
    }
}

# method: is_boolean($value)
#
# does:   determine whether supplied value is boolean
# detail: checks whether value is one of: 'yes', 'true', 'on', 1,
#         'no, 'false, 'off' or 0
# params: $value - value to be analysed [required]
# prints: nil
# return: boolean (undefined if no value provided)
method is_boolean ($value) {
    if ( not defined $value ) { return; }
    $value = $self->boolise($value);
    return $value =~ /(^1$|^0$)/xsm;
}

# method: save_store($ref, $file)
# does:   store data structure in file
# params: $ref  - reference to data structure to be stored
#         $file - file path in which to store data
# prints: nil (except feedback from Storable module)
# return: boolean
# uses:   Storage
# usage:  my $storage_dir = '/path/to/filename';
#         $self->save_store( \%data, $storage_file );
method save_store ($ref, $file) {
    if ( not $ref ) { return; }

    # path must exist
    my $path = $self->get_path($file);
    if ( $path && !-d $path ) {
        confess "Invalid path in '$file'";
    }

    # will overwrite, but warn user
    if ( -e $file ) {
        cluck "Overwriting '$file'";
    }

    # save data
    return Storable::store $ref, $file;
}

# method: retrieve_store($file)
#
# does:   retrieves function data from storage file
# params: $file - file in which data is stored [required]
# prints: nil (except feedback from Storage module)
# return: boolean
# uses:   Storable
# usage:  my $storage_file = '/path/to/filename';
#         my $ref = $self->retrieve_store($storage_file);
#         my %data = %{$ref};
method retrieve_store ($file) {
    if ( not -r $file ) { confess "Cannot read file '$file'"; }
    return Storable::retrieve $file;
}

# method: number_list(@items)
#
# does:   prefix each list item with element index (base = 1)
#         prefix is left padded so each is the same length
# params: @items - list to be modified [required]
# prints: nil
# return: list
# note:   map operation extracted to method as per Perl Best Practice
# uses:   List::Util
method _add_numeric_prefix ($item, $prefix_length) {
    state $index = 1;
    my $index_width   = length $index;
    my $padding_width = $prefix_length - $index_width;
    my $padding       = q{ } x $padding_width;
    my $prefix        = "$padding$index. ";
    $index++;
    $item = "$prefix$item";
    return $item;
}

method number_list (@items) {
    if ( not @items ) { return; }
    my $prefix_length = length scalar @items;
    my $index         = 1;
    my @numbered_list
        = map { $self->_add_numeric_prefix( $_, $prefix_length ) } @items;
    return @numbered_list;
}

# method: denumber_list(@list)
#
# does:   remove number prefixes added by method 'number_list'
# params: @items - list to modify [required]
# prints: nil
# return: list
# note:   map operation extracted to method as per Perl Best Practice
method _remove_numeric_prefix ($item) {
    $item =~ s/^\s*\d+[.]\s+//xsm;
    $item;
}

method denumber_list (@items) {
    map { $self->_remove_numeric_prefix($_) } @items;
}

# method: shorten($string, [$limit], [$cont])
#
# does:   truncate text if too long
# params: $string - string to shorten [required]
#         $length - length at which to truncate, must be > 10
#                   [optional, default=72]
#         $cont   - continuation sequence at end of truncated string
#                   must be no longer than three characters
#                   [optional, default='...']
# prints: nil
# return: scalar string
method shorten ($string, $limit, $cont) {

    # variables
    my $default_limit = 72;
    my $default_cont  = '...';

    # - cont
    if ( not $cont ) {
        $cont = $default_cont;
    }
    if ( length $cont > 3 ) {
        cluck "Continuation sequence '$cont' too long; using default '$cont'";
        $cont = $default_cont;
    }

    # - limit
    if ( not $limit ) {
        $limit = $default_limit;
    }
    if ( not $self->valid_positive_integer($limit) ) {
        cluck "Non-integer '$limit'; using default '$default_limit'";
        $limit = $default_limit;
    }
    if ( $limit <= 10 ) {
        cluck "Limit '$limit' too short; using default '$default_limit'";
        $limit = $default_limit;
    }
    $limit = $limit - length $cont;

    # - string
    if ( not $string ) {
        confess q{No parameter 'string' provided at};
    }

    # truncate if necessary
    if ( length($string) > $limit ) {
        $string = substr( $string, 0, $limit - 1 ) . $cont;
    }

    return $string;
}

# method: internet_connection()
#
# does:   determine whether an internet connection can be found
# params: nil
# prints: nil
# return: boolean
# uses:   Net::Ping::External
method internet_connection () {
    my $connected;
    foreach my $url ( $self->_ping_urls ) {
        if ( Net::Ping::External::ping( hostname => $url ) ) {
            $connected = $TRUE;
            last;
        }
    }
    if ($connected) { return $TRUE; }
    return;
}

# method: cwd()
#
# does:   get current directory
# params: nil
# prints: nil
# return: scalar
#  uses:  Cwd
method cwd () {
    return Cwd::getcwd();
}

# method: true_path($filepath)
#
# does:   convert relative filepath to absolute
# params: $filepath - filepath to convert [required]
# prints: nil
# return: scalar
# uses:   Cwd
# detail: if an absolute filepath is provided it is returned unchanged
# detail: Symlinks will be followed and converted to their true filepaths
# alert:  directory path does not exist
#           if the directory part of the filepath does not exist the
#           entire filepath is returned unchanged; this is a compromise --
#           there may be times when you want to normalise a non-existent
#           path, i.e, to collapse '../' parent directories; abs_path will
#           silently return an empty result if an invalid directory is
#           included in the path; since safety should always take priority,
#           the method will return the supplied filepath unchanged if the
#           directory part does not exist
# alert:  double quote variable parameter
#           if passing a variable to this function it should be double
#           quoted; if not, passing a value like './' results in an error
#           as the value is somehow reduced to an empty value
method true_path ($filepath) {
    if ( not $filepath ) { return; }

    # invalid directory path causes abs_path to fail, so return unchanged
    my $path = $self->get_path($filepath);
    if ( $path and not -d $path ) { return $filepath; }

    # do conversion
    return abs_path($filepath);
}

# method: pid_running($pid)
#
# does:   determines whether process id is running
#         reloads processes each time method is called
# params: $pid - pid to look for [required]
# prints: nil
# return: boolean scalar
method pid_running ($pid) {
    if ( not $pid ) { return; }
    $self->_reload_processes;
    my @pids = $self->_pids();
    return scalar grep {/^$pid$/xsm} @pids;    # force scalar context
}

# method: process_running($cmd, [$match_full])
#
# does:   determine whether process is running
# params: $cmd         - command to search for [required]
#         $ match_full - whether to require match against entire process
#                        [optional, default=false]
# prints: nil
# return: boolean
# note:   if the command string is part of a parameter passed to a script
#         which then calls this method, and partial matching is in effect,
#         the script process will match and result in a false positive
method process_running ($cmd, $match_full = $FALSE) {

    # set and check variables
    if ( not $cmd ) { return; }
    $self->_reload_processes;
    my @cmds = $self->_commands;

    # search process commands for matches
    if ($match_full) {
        return scalar grep {/^$cmd$/xsm} @cmds;
    }
    else {
        return scalar grep {/$cmd/xsm} @cmds;
    }
}

# method: _file_mime_type($filepath)
#
# does:   determine mime type of file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
# uses:   File::MimeInfo
# note:   this method previously used File::Type::mime_type but that
#         module incorrectly identifies some mp3 files as
#         'application/octet-stream'
# note:   alternatives include File::MMagic and File::MMagic:Magic
method _file_mime_type ($filepath) {
    if ( not $filepath )    { confess 'No filepath provided'; }
    if ( not -r $filepath ) { confess "Invalid filepath '$filepath'"; }
    return File::MimeInfo->new()->mimetype($filepath);
}

# method: _is_mimetype($filepath, $mimetype)
#
# does:   determine whether file is a specified mimetype
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
#         $mimetype - mime type to test for [required]
# prints: nil
# return: scalar boolean
# uses:   File::MimeInfo
method _is_mimetype ($filepath, $mimetype) {
    if ( not $mimetype ) { confess 'No mimetype provided'; }
    my $filetype = $self->_file_mime_type($filepath);
    if ( not $filetype ) { return; }
    return $filetype =~ m{^$mimetype\z}xsm;
}

# method: is_mp3($filepath)
#
# does:   determine whether file is an mp3 file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
method is_mp3 ($filepath) {
    return $self->_is_mimetype( $filepath, 'audio/mpeg' );
}

# method: is_mp4($filepath)
#
# does:   determine whether file is an mp3 file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
method is_mp4 ($filepath) {
    return $self->_is_mimetype( $filepath, 'video/mp4' );
}

1;

__END__

=encoding utf-8

=head1 NAME

Dn::Common - common methods for use by perl scripts

=head1 SYNOPSIS

    use Dn::Common;

=head1 DESCRIPTION

Provides methods used by Perl scripts. Can be used to create a standalone object providing these methods; or as base class for derived module or class.

=head1 SUBROUTINES/METHODS

=head2 config_param($parameter)

=head3 Configuration file syntax

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

Warning: Mixing formats in the same file will cause a fatal error.

The key is provided as the argument to method, e.g.:
    $parameter1 = $cp->config_param('key1');

If the ini file format is used with block headings, the block heading must be included using dot syntax, e.g.:
    $parameter1 = $cp->config_param('block1.key1');

=head3 Configuration file locations and names

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

As it is possible to retrieve multiple values for a single key, this method returns a list of parameter values. If the result is obtained in scalar context it gives the number of values - this can be used to confirm a single parameter result where only one is expected. 

=head2 suspend_screensaver([$title], [$msg])

=head3 Purpose

Suspend kde screensaver if it is present.

The screensaver is suspended until it is restored (see method C<restore_screensaver>) or the process that suspended the screensaver exits.

=head3 Parameters

=over 4

=over

=item $title

Message box title. Note that feedback is given in a popup notification (see method C<notify_sys>).

Optional. Default: name of calling script.

=item $msg

Message explaining suspend request. It is passed to the screensaver object and is not seen by the user.

Named parameter.

Optional. Default: 'request from $PID'.

=back

=back

=head3 Prints

User feedback indicating success or failure.

=head3 Returns

Boolean. Whether able to successfully suspend the screensaver.

=head3 Usage

    $cp->suspend_screensaver('Playing movie');
    $cp->suspend_screensaver(
        'Playing movie', msg => 'requested by my-movie-player'
    );

=head2 restore_screensaver([$title])

=head3 Purpose

Restore suspended kde screensaver.

Only works if used by the same process that suspended the screensaver (See method C<suspend_screensaver>. The screensaver is restored automatically is the process that suspended the screensaver exits.

=head3 Parameters

=over 4

=over

=item $title

Message box title. Note that feedback is given in a popup notification (see method C<notify_sys>).

Optional. Default: name of calling script.

=back

=back

=head3 Prints

User feedback indicating success or failure.

=head3 Returns

Boolean. Whether able to successfully suspend the screensaver.

=head2 notify(@messages, [$prepend])

=head3 Purpose

Display console message.

=head3 Parameters

=over 4

=over

=item @messages

Message lines. Respects newlines if enclosed in double quotes.

Required.

=item $prepend

Whether to prepend each message line with name of calling script.

Named parameter. Boolean.

Optional. Default: false.

=back

=back

=head3 Prints

Messages.

=head3 Returns

Nil.

=head3 Usage

    $cp->notify('File path is:', $filepath);
    $cp->notify('File path is:', $filepath, prepend => $TRUE);

=head2 abort(@messages, [$prepend])

=head3 Purpose

Display console message and abort script execution.

=head3 Parameters

=over 4

=over

=item @messages

Message lines. Respects newlines if enclosed in double quotes.

Required.

=item $prepend

Whether to prepend each message line with name of calling script.

Named parameter. Boolean.

Optional. Default: false.

=back

=back

=head3 Prints

Messages followed by abort message.

=head3 Returns

Nil.

=head3 Usage

    $cp->abort('We failed');
    $cp->abort('We failed', prepend => $TRUE);

=head2 notify_sys($message, [$title], [$type], [$icon], [$time])

=head3 Purpose

Display message to user in system notification area

=head3 Parameters

=over 4

=over

=item $message

Message content.

Note there is no guarantee that newlines in message content will be respected.

Required.

=item $title

Message title.

Optional. Default: name of calling script.

=item $type

Type of message. Must be one of 'info', 'question', 'warn' and 'error'.

Optional. Default: 'info'.

=item $icon

Message box icon filepath.

Optional. A default icon is provided for each message type.

=item $time

Message display time (msec).

Optional. Default: 10,000.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Boolean: whether able to display notification.

=head3 Usage

    $cp->notify_sys('Operation successful!', title => 'Outcome')

=head3 Caution

Do not call this method from a spawned child process -- the 'show()' call in the last line of this method causes the child process to hang without any feedback to user.

=head2 logger($message, [$type])

=head3 Purpose

Display message in system log.

There are four message types: 'debug', 'notice', 'warning' and 'error'. Not all message types appear in all system logs. On Debian, for example, /var/log/messages records only notice and warning log messages while /var/log/syslog records all log messages.

Method dies if invalid message type is provided.

=head3 Parameters

=over 4

=over

=item $message

Message content.

Required.

=item $type

Type of log message. Must be one of 'debug', 'notice', 'warning' and 'error'.

Method dies if invalid message type is provided.

Optional. Default: 'notice'.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Nil. Note method dies if invalid message type is provided.

=head3 Usage

    $cp->logger('Widget started');
    $cp->logger( 'Widget died unexpectedly!', 'error' );

=head2 extract_key_value($key, @items)

=head3 Purpose

Provided with a list that contains a key-value pair as a sequential pair of elements, return the value and the list-minus-key-and-value.

=head3 Parameters

=over 4

=over

=item $key

Key of the key-value pair.

Required.

=item @items

The items containing key and value.

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

List with first element being the target value (undef if not found) and subsequent elements being the original list minus key and value.

=head3 Usage

    my ($value, @list) = $cp->($key, @list);

=head2 clear_screen()

=head3 Purpose

Clear the terminal screen.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Nil.

=head3 Usage

    $cp->clear_screen;

=head2 input_choose($prompt, @options, [$prepend])

=head3 Purpose

User selects option from a menu.

=head3 Parameters

=over 4

=over

=item $prompt

Menu prompt.

Required.

=item @options

Menu options.

Required.

=item $prepend

Flag indicating whether to prepend script name to prompt.

Named parameter. Scalar boolean.

Optional. Default: false.

=back

=back

=head3 Prints

Menu and user interaction.

=head3 Returns

Return value depends on the calling context:

=over 4

=over

=item scalar

Returns scalar (undef if choice cancelled).

=item list

Returns list (empty list if choice cancelled).

=back

=back

=head3 Usage

    my $value = undef;
    my @options = ( 'Pick me', 'No, me!' );
    while ($TRUE) {
        $value = $self->input_choose( "Select value:", @options );
        last if $value;
        say "Invalid choice. Sorry, please try again.";
    }

=head2 input_ask($prompt, [$default], [$prepend])

=head3 Purpose

Obtain input from user.

This method is intended for entering short values. Once the entered text wraps to a new line the user cannot move the cursor back to the previous line.

Use method 'input_large' if the value is likely to be longer than a single line.

=head3 Parameters

=over 4

=over

=item $prompt

User prompt. If user uses 'prepend' option (see below) the script name is prepended to the prompt.

=item $default

Default input.

Optional. Default: none.

=item $prepend

Whether to prepend the script name to the prompt.

Named parameter. Boolean.

Optional. Default: false.

=back

=back

=head3 Prints

User interaction.

=head3 Returns

User's input (scalar).

=head3 Usage

    my $value;
    my $default = 'default';
    while (1) {
        $value = $self->input_ask( "Enter value:", $default );
        last if $value;
    }

=head2 input_large($prompt, [$default], [$prepend])

=head3 Purpose

Obtain input from user.

This method is intended for entry of data likely to be longer than a single line. Use method 'input_ask' if entering a simple (short) value. An editor is used to enter the data. The default editor is used. If no default editor is set, vi(m) is used.

When the editor opens it displays some boilerplate, the prompt, a horizontal rule (a line of dashes), and the default value if provided. When the editor is closed all lines up to and including the first horizontal rule are deleted. The user can get the same effect by deleting in the editor all lines up to and including the first horizontal rule.

Use method 'input_ask' if the prompt and input will fit on a single line.

=head3 Parameters

=over 4

=over

=item $prompt

User prompt. If user uses 'prepend' option (see below) the script name is prepended to the prompt.

=item $default

Default input.

Optional. Default: none.

=item $prepend

Whether to prepend the script name to the prompt.

Named parameter. Boolean.

Optional. Default: false.

=back

=back

=head3 Prints

User interaction.

=head3 Returns

User's input as list, split on newlines in user input.

=head3 Usage

Here is a case where input is required:

    my @input;
    my $default = 'default';
    my $prompt = 'Enter input:';
    while (1) {
        @input = $self->input_large( $prompt, $default );
        last if @input;
        $prompt = "Input is required\nEnter input:";
    }

=head2 input_confirm($question, [$prepend])

=head3 Purpose

User answers y/n to a question.

=head3 Parameters

=over 4

=over

=item $question

Question to elicit user response. If user uses 'prepend' option (see below) the script name is prepended to it.

Can be multi-line, i.e., enclose in double quotes and include '\n' newlines. After the user answers, all but first line of question is removed from the screen. For that reason, it is good style to make the first line of the question a short summary, and subsequent lines can give additional detail.

Required.

=item $prepend

Whether to prepend the script name to the question.

Boolean.

Optional. Default: false.

=back

=back

=head3 Prints

User interaction.

=head3 Return

Scalar boolean.

=head3 Usage

    my $prompt = "Short question?\n\nMore\nmulti-line\ntext.";
    if ( input_confirm($prompt) ) {
        # do stuff
    }

=head2 display($string)

=head3 Purpose

Displays text on screen with word wrapping.

=head3 Parameters

=over 4

=over

=item $string

Test for display.

Required.

=back

=back

=head3 Print

Text for screen display.

=head3 Return

Nil.

=head3 Usage

    $cp->display($long_string);

=head2 vim_print($type, @messages)

=head3 Purpose

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

=head3 Parameters

=over 4

=over

=item $type

Type of text. Determines colour scheme.

Must be one of: 'title', 'error', 'warning', 'prompt' and 'normal'. Case-insensitive. Can supply a partial value, down to and including just the first letter.

Required.

=item @messages

Content to display.

Supplied strings can contain escaped double quotes.

Required.

=back

=back

=head3 Prints

Messages in the requested colour scheme.

=head3 Returns

Nil.

=head3 Usage

    $cp->vim_print( 't', 'This is a title' );

=head2 vim_printify($type, $message)

=head3 Purpose

Modifies a single string to be included in a List to be passed to the 'vim_list_print' method. The string is given a prefix that signals to 'vim_list_print' what format to use. The prefix is stripped before the string is printed.

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

=head3 Parameters

=over 4

=over

=item $type

Type of text. Determines colour scheme.

Must be one of: 'title', 'error', 'warning', 'prompt' and 'normal'. Case-insensitive. Can supply a partial value, down to and including just the first letter.

Required.

=item $message

Content to modify.

Supplied string can contain escaped double quotes.

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Modified string.

=head3 Usage

    $cp->vim_printify( 't', 'This is a title' );

=head2 vim_list_print(@messages)

=head3 Purpose

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

=head3 Parameters

=over 4

=over

=item @messages

Each element of the list can be printed in a different style. Element strings need to be prepared using the 'vim_printify' method. See the 'vim_printify' method for an example.

Required.

=back

=back

=head3 Prints

Messages in requested styles.

=head3 Returns

Nil.

=head2 listify(@items)

=head3 Purpose

Tries to convert scalar, array and hash references in list to sequences of simple scalars. For other reference types a warning is issued.

=head3 Parameters

=over 4

=over

=item @items

Items to convert to simple list.

=back

=back

=head3 Prints

Warning messages for references other than scalar, array and hash.

=head3 Returns

Simple list.

=head2 browse($title, $text)

=head3 Purpose

Displays large volume of text in default editor and then returns viewer to original screen.

=head3 Parameters

=over 4

=over

=item $title

Title is prepended to displayed text (along with some usage instructions) and is used in creating the temporary file displayed in the editor.

Required.

=item $text

Text to display.

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Nil.


=head2 prompt([message])

=head3 Purpose

Display message and prompt user to press any key.

=head3 Parameters

=over 4

=over

=item Message

Message to display.

Optional. Default: 'Press any key to continue'.

=back

=back

=head3 Prints

Message.

=head3 Returns

Nil.

=head2 get_path($filepath)

=head3 Purpose

Get path from filepath.

=head3 Parameters

=over 4

=over

=item $filepath

File path. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar path.

=head2 executable_path($exe)

=head3 Purpose

Get path of executable.

=head3 Parameters

=over 4

=over

=item $exe

Short name of executable. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Return

Scalar filepath: absolute path to executable if executable exists.

Scalar boolean: returns undef If executable does not exist.

=head2 make_dir($dir_path)

=head3 Purpose

Make directory recursively.

=head3 Parameters

=over 4

=over

=item $dir_path

Directory path to create. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Return

Scalar boolean. If directory already exists returns true.

=head2 files_list([$directory])

=head3 Purpose

List files in directory. Uses current directory if no directory is supplied.

=head3 Parameters

=over 4

=over

=item $directory

Directory path.

Optional. Default: current directory.

=back

=back

=head3 Prints

Nil.

=head3 Returns

List. Dies if operation fails.

=head2 dirs_list([$directory])

=head3 Purpose

List subdirectories in directory. Uses current directory if no directory is supplied.

=head3 Parameters

=over 4

=over

=item $directory

Directory from which to obtain file list.

Optional. Default: current directory.

=back

=back

=head3 Prints

Nil (error message if dies).

=head3 Returns

List (dies if operation fails).

=head2 backup_file($file)

=head3 Purpose

Backs up file by renaming it to a unique file name. Will simply add integer to file basename.

=head3 Parameters

=over 4

=over

=item $file

File to back up. 

Required.

=back

=back

=head3 Prints

Nil.

=head4 Returns

Scalar filename.

=head2 valid_positive_integer($value)

=head3 Purpose

Determine whether supplied value is a valid positive integer (zero or above).

=head3 Parameters

=over 4

=over

=item $value

Value to test. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 valid_positive_integer($value)

=head3 Purpose

Determine whether supplied value is a valid positive integer (zero or above).

=head3 Parameters

=over 4

=over

=item $value

Value to test. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 today()

=head3 Purpose

Get today as an ISO-formatted date.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

ISO-formatted date.

=head2 offset_date($offset)

=head3 Purpose

Get a date offset from today. The offset can be positive or negative.

=head3 Parameters

=over 4

=over

=item $offset

Offset in days. Can be positive or negative. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

ISO-formatted date.

=head2 day_of_week([$date])

=head3 Purpose

Get the day of week that the supplied date falls on.

=head3 Parameters

=over 4

=over

=item $date

Date to analyse. Must be in ISO format.

Optional. Default: today.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar day name.

=head2 konsolekalendar_date_format([$date])

=head3 Purpose

Get date formatted in same manner as konsolekalendar does in its output. An example date value is 'Tues, 15 Apr 2008'. The corresponding strftime format string is '%a, %e %b %Y'.

=head3 Parameters

=over 4

=over

=item $date

Date to convert. Must be in ISO format.

Optional, Default: today.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar date string.

=head2 valid_date($date)

=head3 Purpose

Determine whether date is valid and in ISO format.

=head3 Parameters

=over 4

=over

=item $date

Candidate date. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 sequential_dates($date1, $date2)

=head3 Purpose

Determine whether supplied dates are in chronological sequence.

Both dates must be in ISO format or method will return failure. It is recommended that date formats be checked before calling this method.

=head3 Parameters

=over 4

=over

=item $date1

First date. ISO format. 

Required.

=item $date2

Second date. ISO format. 

Required.

=back

=back

=head3 Prints

Nil. Error message if dates not in ISO-format.

=head3 Returns

Boolean.

=head2 future_date($date)

=head3 Purpose

Determine whether supplied date occurs in the future, i.e, today or after today.

=head3 Parameters

=over 4

=over

=item $date

Date to compare. Must be ISO format. 

Required.

=back

=back

=head3 Prints

Nil. (Error if invalid date.)

=head3 Return

Boolean. (Dies if invalid date.)

=head2 valid_24h_time($time)

=head3 Purpose

Determine whether supplied time is valid.

=head3 Parameters

=over 4

=over

=item $time

Time to evaluate. Must be in 'HH::MM' format (leading zero can be dropped).

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 sequential_24h_times($time1, $time2)

=head3 Purpose

Determine whether supplied times are in chronological sequence, i.e., second time occurs after first time. Assume both times are from the same day.

=head3 Parameters

=over 4

=over

=item $time1

First time to compare. 24 hour time format. 

Required.

=item $time2

Second time to compare. 24 hour time format. 

Required.

=back

=back

=head3 Prints

Nil. (Error if invalid time.)

=head3 Returns

Boolean (Dies if invalid time.)

=head2 entitise($string)

=head3 Purpose

Perform standard conversions of reserved characters to HTML entities.

=head3 Parameters

=over 4

=over

=item $string

String to analyse. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 deentitise($string)

=head3 Purpose

Perform standard conversions of HTML entities to reserved characters.

=head3 Parameters

=over 4

=over

=item $string

String to analyse. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 tabify($string, [$tab_size])

=head3 Purpose

Covert tab markers ('\t') in string to spaces. Default tab size is four spaces.

=head3 Parameters

=over 4

=over

=item $string

String in which to convert tabs. 

Required.

=item $tab_size

Number of spaces in each tab. Integer.

Optional. Default: 4.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 trim($string)

=head3 Purpose

Remove leading and trailing whitespace.

=head3 Parameters

=over 4

=over

=item $string

String to be converted. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 boolise($value)

=head3 Purpose

Convert value to boolean.

Specifically, converts 'yes', 'true' and 'on' to 1, and convert 'no, 'false, and 'off' to 0. Other values are returned unchanged.

=head3 Parameters

=over 4

=over

=item $value

Value to analyse. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 is_boolean($value)

=head3 Purpose

Determine whether supplied value is boolean.

Specifically, checks whether value is one of: 'yes', 'true', 'on', 1, 'no, 'false, 'off' or 0.

=head3 Parameters

=over 4

=over

=item $value

Value to be analysed. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Boolean. (Undefined if no value provided.)

=head2 save_store($ref, $file)

=head3 Purpose

Store data structure in file.

=head3 Parameters

=over 4

=over

=item $ref

Reference to data structure (usually hash or array) to be stored.

=item $file

File path in which to store data.

=back

=back

=head3 Prints

Nil (except feedback from Storable module).

=head3 Returns

Boolean.

=head3 Usage

    my $storage_dir = '/path/to/filename';
    $self->save_store( \%data, $storage_file );

=head2 retrieve_store($file)

=head3 Purpose

Retrieves function data from storage file.

=head3 Parameters

=over 4

=over

=item $file

File in which data is stored. 

Required.

=back

=back

=head3 Prints

Nil (except feedback from Storage module).

=head3 Returns

Boolean.

=head3 Usage

    my $storage_file = '/path/to/filename';
    my $ref = $self->retrieve_store($storage_file);
    my %data = %{$ref};

=head2 number_list(@items)

=head3 Purpose

Prefix each list item with element index. The index base is 1.

The prefix is left padded with spaces so each is the same length.

Example: 'Item' becomes ' 9. Item'.

=head3 Parameters

=over 4

=over

=item @items

List to be modified. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

List.

=head2 denumber_list(@list)

=head3 Purpose

Remove number prefixes added by method 'number_list'.

=head3 Parameters

=over 4

=over

=item @items

List to modify. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Return

List.

=head2 shorten($string, [$limit], [$cont])

=head3 Purpose

Truncate text with ellipsis if too long.

=head3 Parameters

=over 4

=over

=item $string

String to shorten. 

Required.

=item $length

Length at which to truncate. Must be integer > 10.

Optional. Default: 72.

=item $cont

Continuation sequence placed at end of truncated string to indicate shortening. Cannot be longer than three characters.

Optional. Default: '...'.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 internet_connection()

=head3 Purpose

Checks to see whether an internet connection can be found.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 cwd()

=head3 Purpose

Provides current directory.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string

=head2 true_path($filepath)

=head3 Purpose

Converts relative to absolute filepaths. Any filepath can be provided to this method -- if an absolute filepath is provided it is returned unchanged. Symlinks will be followed and converted to their true filepaths.

If the directory part of the filepath does not exist the entire filepath is returned unchanged. This is a compromise. There may be times when you want to normalise a non-existent path, i.e, to collapse '../' parent directories. The 'abs_path' function can handle a filepath with a nonexistent file. Unfortunately, however, it will silently return an empty result if an invalid directory is included in the path. Since safety should always take priority, the method will return the supplied filepath unchanged if the directory part does not exist.

WARNING: If passing a variable to this function it should be double quoted. If not, passing a value like './' results in an error as the value is somehow reduced to an empty value.

=head3 Parameters

=over 4

=over

=item $filepath

Path to analyse. If a variable should be double quoted (see above).

Required.

=back

=back

=head3 Prints

Nil

=head3 Returns

Scalar filepath.

=head2 pid_running($pid)

=head3 Purpose

Determines whether process id is running.

=head3 Parameters

=over 4

=over

=item $pid

Process ID to search for. 

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Boolean scalar.

=head2 process_running($cmd, [$match_full])

=head3 Purpose

Determines whether process is running. Matches on process command. Can match against part or all of process commands.

=head3 Parameters

=over 4

=over

=item $cmd

Command to search for. 

Required.

=item $match_full

Whether to require match against entire process command.

Optional. Default: false.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Boolean scalar.

=head3 is_mp3($filepath)

=head3 Purpose

Determine whether file is an mp3 file.

=head3 Parameters

=over 4

=over

=item $filepath

File to analyse.

Required. Method dies if $filepath is not provided or is invalid.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head3 is_mp4($filepath)

=head3 Purpose

Determine whether file is an mp4 file.

=head3 Parameters

=over 4

=over

=item $filepath

File to analyse.

Required. Method dies if $filepath is not provided or is invalid.

=back

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.






=head1 DEPENDENCIES

=head2 autodie

Automated error checking of 'open' and 'close' functions.

Debian: provided by package 'libautodie-perl'.

=head2 Config::Simple

Reads and parses configuration files.

Provides the 'import_from' function.

Debian: provided by package 'libconfig-simple-perl'.

=head2 Cwd

Used to normalise paths, including following symlinks and collapsing relative
paths. Also used to provide current working directory.

Provides the 'abs_path' and 'getcwd' functions for these purposes,
respectively.

Debian: provided by package 'libfile-spec-perl'.

=head2 Data::Dumper::Simple

Used for displaying variables.

Debian: provided by package 'libdata-dumper-simple-perl'.

=head2 Date::Simple

Used for writing date strings.

Debian: provided by package 'libdate-simple-perl'.

=head2 Desktop::Detect

Used for detecting KDE desktop. Uses 'detect_desktop' function.

Debian: provided by package 'libdesktop-detect-perl'.

=head2 File::Basename

Parse file names.

Provides the 'fileparse' method.

Debian: provided by package 'perl'.

=head2 File::Copy

Used for file copying.

Provides the 'copy' and 'move' functions.

Debian: provided by package 'perl-modules'.

=head2 File::MimeInfo

Provides 'mimetype' method for getting mime-type information about mp3 files.

Debian: provided by package 'libfile-mimeinfo-perl'.

Note: Previously used File::Type and its 'mime_type' method to get file
mime-type information but that module incorrectly identifies some mp3 files as
'application/octet-stream'. Other alternatives are File::MMagic and
File::MMagic:Magic.

=head2 File::Util

Used for various file and directory operations, including recursive directory
creation and extracting filename and/or dirpath from a filepath.

Debian: provided by package 'libfile-util-perl'.

=head2 File::Which

Used for finding paths to executable files.

Provides the 'which' function which mimics the bash 'which' utility.

Debian: provided by package 'libfile-which-perl'.

=head2 Gtk2::Notify

Provides access to libnotify.

Provides the 'set_timeout' and 'show' functions.

Uses this nonstandard invocation recommended by the module man page:

    use Gtk2::Notify -init, "$0";

Debian: provided by package 'libgtk2-notify-perl'.

=head2 HTML::Entities

Used for converting between html entities and reserved characters. Provides 'encode_entities' and 'decode_entities' methods.

Debian: provided by package: 'libhtml-parser-perl'.

Debian: provided by package 'libnet-ping-external-perl'.

=head2 Logger::Syslog

Interface to system log.

Provides functions 'debug', 'notice', 'warning' and 'error'.

Some system logs only record some message types. On debian systems, for
example, /var/log/messages records only 'notice' and 'warning' message types
while /var/log/syslog records all message types.

Debian: provided by package 'liblogger-syslog-perl'.

=head2 namespace::autoclean

Used to optimise Mouse.

Debian: provided by package 'libnamespace::autoclean'.

=head2 Mouse

Use modern perl.

Debian: provided by 'libmouse-perl'.

=head2 Mouse::Util::TypeConstraints

Used to enhance Mouse.

Debian: provided by 'libmouse-perl'.

=head2 MouseX::NativeTraits

Used to enhance Mouse.

Debian: provided by package 'libmousex-nativetraits-perl'.

=head2 Net::DBus

Used in manipulating DBus services.

Debian: provided by package 'libnet-dbus-perl'.

=head2 Proc::ProcessTable

Provides access to system process table, i.e., output of 'ps'.

Provides the 'table' method.

Debian: provided by package 'libproc-processtable-perl'.

=head2 Net::Ping::External

Cross-platform interface to ICMP "ping" utilities. Enables the pinging of
internet hosts.

Provides the 'ping' function.

=head2 Readonly

Use modern perl.

Debian: provided by package 'libreadonly-perl'

=head2 Storable

Used for storing and retrieving persistent data.

Provides the 'store' and 'retrieve' functions.

Debian: provided by package 'perl'.

=head2 Term::ANSIColor

Used for user input.

Provides the 'colored' function.

Debian: provided by package 'perl-modules'.

=head2 Term::Clui

Used for user input.

Provides 'choose', 'ask', 'edit' and 'confirm' functions.

Is configured to not remember responses. To override put this command after this module is called:

    $ENV{'CLUI_DIR'} = "ON";

Debian: provided by package 'libperl-term-clui'.

=head2 Term::ReadKey

Used for reading single characters from keyboard.

Provides the 'ReadMode' and 'ReadKey' functions.

Debian: provided by package 'libterm-readkey-perl'.

=head2 Test::NeedsDisplay

Prevents build error caused by Gtk2::Notify. The module tests require a display but cannot find one. Test::NeedsDisplay provides a fake display.

Debian: provided by package 'libtest-needsdisplay-perl'.

=head2 Text::Wrap

Used for formatting text into readable paragraphs.

Provides the 'wrap' function.

Debian: provided by package 'perl-base'.

=head2 Time::Simple

Used for validating and comparing times.

Debian: not available.

head1 BUGS AND LIMITATIONS

Report to module author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
