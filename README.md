### logger()

Display message in system log.

There are four message types: 'debug', 'notice', 'warning' and 'error'. One of the method parameters specifies message type -- if none is specified the default message type 'notify' is used. The method will die if an invalid message type is passed.

Not all message types appear in all system logs. On Debian, for example, /var/log/messages records only notice and warning log messages while /var/log/syslog records all log messages.

Parameters: \[ 0 = class \] , 1 = message , 2 = message type (case-insensitive, optional, default = 'notice').

Examples:

    $cp->logger( "Widget started" );
    $cp->logger( "Widget died unexpectedly!" , "error" );

Return type: Boolean (whether able to display notification).

### abort()

Abort script with error message. Message may be prepended with scriptname and the associated method 'sc\_abort' is also available (see method 'notify' for the logic used). 

Parameters: \[ 0 = class \] , 1 = prepend (boolean, optional) , 1|2 = message ,
                            2 = message ...

Return type: N/A.

### clear\_screen()

Clear the terminal screen.

Parameters: (0 = class).

Returns: NIL.

### input\_choose()

User selects from a menu. The scriptname may be prepended to the prompt and the associated method 'sc\_input\_choose' is also available (see method 'notify' for the logic used).

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

### input\_ask()

User enters a value. The scriptname may be prepended to the prompt and the associated method 'sc\_input\_ask' is also available (see method 'notify' for the logic used).

This method is intended for entering short values. Once the entered text wraps to a new line the user cannot move the cursor back to the previous line.

Use method 'input\_large' if the value is likely to be longer than a single line.

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

### input\_large()

User enters data. The scriptname may be prepended to the prompt and the associated method 'sc\_input\_large' is also available (see method 'notify' for the logic used).

This method is intended for entry of data likely to be longer than a single line. Use method 'input\_ask' if entering a simple (short) value. An editor is used to enter the data. The default editor is used. If no default editor is set, vi(m) is used.

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

### input\_confirm()

User answers y/n to a question. The scriptname may be prepended to the question and the associated method 'sc\_input\_confirm' is also available (see method 'notify' for the logic used).

If the question is multi-line, after the answer is supplied only the first line is left on screen. The first line should be a short summary question with subsequent lines holding further information.

Parameters: (0 = class), 1 = prepend (boolean , optional) , 1|2 = question.

Return type: Boolean.

Common usage:

    if ( input_confirm( "Short question?\n\nMore\nmulti-line\ntext." ) ) {
        # do stuff
    }

### display()

Displays screen text with word wrapping.

Parameters: (0 = class), 1 = display string.

Common usage:

    display( <$scalar> );

### pecho()

Wrapper for bash 'echo' command.

Parameters: (0 = class), 1 = display string.

Common usage:

    pecho( <$scalar> );

### pechon()

Wrapper for bash 'echo -n' command.

Parameters: (0 = class), 1 = display string.

Common usage:

    pechon( <$scalar> );

### underline()

Wrap text in bash formatting codes that result in underlining.

Parameters: (0 = class), 1 = display string.

Common usage:

    underline( '<text>' );

### vim\_print()

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

Parameters: \[ 0 = class \] , 1 = message(s) (scalar|arrayref) , 2 = type ('title'|'error'|'warning'|'prompt'|'normal') (optional) (default = 'normal')

Return type: N/A.

### vim\_printify()

Modifies a single string to be included in a List to be passed to the 'vim\_list\_printify' method. The string is given a prefix that signals to 'vim\_list\_printify' what format to use. The prefix is stripped before the string is printed.

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

Parameters: \[ 0 = class \] , 1 = message , 2 = type ('title'|'error'|'warning'|'prompt'|'normal') (optional) (default = 'normal')

Return type: N/A.

### vim\_list\_print()

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

Each element of the list can be printed in a different style. Element strings need to be prepared using the 'vim\_printify' method. See the 'vim\_printify' method for an example.

Parameters: \[ 0 = class \] , 1 = array reference.

Return type: N/A.

### browse()

Displays large volume of text in default editor and then returns viewer to original screen.

Parameters: (0 = class), 1 = title , 2 = text.

Common usage:

    browse( <$title> , <$text> );

### prompt()

Display message and prompt user to press any key.  Default message: 'Press any key to continue'.

Parameters: \[ 0 = class \] , 1 = message (optional).

Returns: NIL.

### get\_path()

Return path from filepath.

Parameters: \[ 0 = class \] , 1 = filepath.

Return type: String.

### executable\_path()

Return path of executable. Mimics bash 'which' utility. Returns absolute path to executable if executable exists. If executable does not exist, it returns undef.

Parameters: \[ 0 = class \] , 1 = executable name.

Return type: String.

### make\_dir()

Make directory recursively.

Parameters: \[ 0 = class \] , 1 = dirpath.

Return type: String.

### files\_list()

List files in directory. Uses current directory if no directory is supplied.

Parameters: \[ 0 = class \] , 1 = dirpath (optional).

Return type: Array reference.

### dirs\_list()

List subdirectories in directory. Uses current directory if no directory is supplied.

Parameters: \[ 0 = class \] , 1 = dirpath (optional).

Return type: Array reference.

### backup\_file()

Backs up file by renaming it to a unique file name. Will simply add integer to file basename.

Uses 'move' function from File::Copy.

Parameters: \[ 0 = class \] , 1 = file.

Return type: N/A.

### listify()

Designed for functions where arguments may be passed as a sequence of scalars, an array (which is handled as a sequence of scalars), or an array reference. The methood can handle a mixture of scalars and array references.

Any other type of reference is ignored, though a warning is printed.

Parameters: \[ 0 = class \] , 1+ = array\_ref|scalar.

Return type: Array reference.

### adb\_run()

A major problem with adb is that it does not return an error code if an operation fails. This method runs an adb command, traps the error code, converts it to perl semantics, and returns it.

Any error messages are printed to the console. 

The preferred parameter is an array reference, but the method tries to gracefully handle strings and arrays. If the method encounters a reference other than ARRAY it will be ignored and an error message printed.

If the parameters are processed and no command elements are derived from them, an error message is printed and an error code returned.

Parameters: \[ 0 = class \] , 1 = array\_ref|scalar , 2+ = array\_ref|scalar.

Return type: Boolean.

### adb\_capture()

A major problem with adb is that it does not return an error code if an operation fails. This method runs an adb command, traps the error code, converts it to perl semantics, and returns it. It also capture any output and returns that.

Any error messages from this method are printed to the console. 

The preferred parameter is an array reference, but the method tries to gracefully handle strings and arrays. If the method encounters a reference other than ARRAY it will be ignored and an error message printed.

If the parameters are processed and no command elements are derived from them, an error message is printed and an error code returned.

Parameters: \[ 0 = class \] , 1 = array\_ref|scalar , 2+ = array\_ref|scalar.

Return type: Array\_ref \[
                scalar (boolean, adb\_success) ,
                array\_ref (adb\_output) 
\]

### valid\_positive\_integer()

Determine whether supplied value is a valid positive integer (zero or above).

Parameters: \[ 0 = class \] , 1 = value.

Return type: Boolean.

### today()

Return today as an ISO-formatted date.

Parameters: \[ 0 = class \].

Return type: String.

### offset\_date()

Return as an ISO-formatted date a date offset from today. The offset can be a positive or negative integer.

Parameters: \[ 0 = class \] , 1 = offset.

Return type: String.

### day\_of\_week()

Return day of week that supplied date falls on. Note that supplied date must be in ISO format. Default date: today.

Parameters: \[ 0 = class \] , 1 = date (optional).

Return type: Scalar <string>.

### konsolekalendar\_date\_format()

Return date formatted in same manner as konsolekalendar does in its output. An example date value is 'Tues, 15 Apr 2008'. The corresponding strftime format string is '%a, %e %b %Y'. Note that supplied date must be in ISO format. Default date: today.

Parameters: \[ 0 = class \] , 1 = date (optional).

Return type: Scalar <string>.

### valid\_date()

Determine whether supplied date is valid.

Parameters: \[ 0 = class \] , 1 = date (YYYY-MM-DD).

Return type: Boolean.

### sequential\_dates()

Determine whether supplied dates are sequential.

Assumes both dates are formatted as ISO dates \[YYY-MM-DD\]. If this is not so, the results may be unpredictable.

Parameters: \[ 0 = class \] , 1 = date (YYYY-MM-DD), 2 = date (YYYY-MM-DD).

Return type: Boolean.

### future\_date()

Determine whether supplied date occurs in the future, i.e, today or after today.

Assumes date is formatted as ISO date \[YYY-MM-DD\]. If this is not so, the results may be unpredictable.

Parameters: \[ 0 = class \] , 1 = date (YYYY-MM-DD).

Return type: Boolean.

### valid\_24h\_time\_hrs()

Provide list of valid hour values for 24-hour time.

Parameters: \[ 0 = class \].

Return type: List.

### valid\_24h\_time\_minsec()

Provide list of valid minute and second values for 24-hour time.

Parameters: \[ 0 = class \].

Return type: List.

### valid\_24h\_time()

Determine whether supplied time is valid.

Parameters: \[ 0 = class \] , 1 = time (HH:MM\[:SS\]).

Return type: Boolean.

### sequential\_24h\_times()

Determine whether supplied times are sequential, i.e., second time occurs after first time. Assume both times are from the same day.

Parameters: \[ 0 = class \] , 1 = time (HH:MM\[:SS\]) , 2 = time (HH:MM\[:SS\]).

Return type: Boolean.

### deentitise()

Perform standard conversions of HTML entities to reserved characters (see function 'entitise' for table of entities).

Parameters: \[ 0 = class \] , 1 = string.

Return type: String.

### entitise()

Perform standard conversions of reserved characters to HTML entities:

    Name             ASCII     Entity
    ----             -----     ------
    ampersand          &       &amp;
    less than          <       &lt;
    greater than       >       &gt;
    quotation mark     "       &quot;
    apostrophe         '       &apos;

Parameters: \[ 0 = class \] , 1 = string.

Return type: String.

### entitise\_apos()

Perform standard conversions of apostrophes (single quotes) to an HTML entity.

Parameters: \[ 0 = class \] , 1 = string.

Return type: String.

### dequote()

Remove quote marks from string.

Parameters: \[ 0 = class \] , 1 = string.

Return type: String.

### tabify()

Covert tab markers ('\\t') in string to spaces. Default tab size is four spaces.

Parameters: \[ 0 = class \] , 1 = string , 2 = tab\_size (optional).

Return type: String.

### trim()

Remove leading and trailing whitespace from string.

Parameters: \[ 0 = class \] , 1 = string.

Return type: String.

### boolise()

Convert value to boolean.

Parameters: \[ 0 = class \] , 1 = value.

Return type: Boolean (integer: 0|1).

### is\_boolean()

Determine whether supplied value is boolean.

Parameters: \[ 0 = class \] , 1 = value.

Return type: Boolean (integer: 0|1).

### save\_store()

Store data structure in file.

Parameters: \[ 0 = class \] , 1 = variable reference , 2 = file.

Return type: Boolean (integer).

Common usage:

    my %functions = $self->functions();
    my $storage_dir = '/path/to/filename';
    $self->save_store( \%functions , $storage_file );

### retrieve\_store()

Retrieves function data from sorage file.

Parameters: \[ 0 = class \] , 1 = file.

Return type: Scalar (function reference).

Common usage:

    my $storage_file = '/path/to/filename';
    my $funcref = $self->retrieve_store( $storage_file );
    $self->set_functions( $funcref );

### read\_config\_files()

Locates all configuration files and loads their parameters and values. Module documentation for Config::Simple give full information on various configuration file formats that can be read. Here are two simple formats that will suffice for most scripts. In each case the key is 'my\_key' and the corresponding value is 'my value'.

    my_key my value
    my_key: my value

Note the value does not need to be enclosed in quotes even if it contains spaces.

If you wish to store multiple values for a single parameter, follow the instructions in the Config::Simple man|pod page for how to format the configuration file.

All values are stored as an array, even if there is only one value for a parameter. See method 'config\_param' for the implications of this.

Uses script name as root of configuration file name if one is not supplied. Searches the following directories in turn (assume configuration file root is 'FOO'):

    ./ , /usr/local/etc , /etc , /etc/FOO , ~/

for the following files, in turn:

    FOOconfig , FOOconf , FOO.config , FOO.conf , FOOrc , .FOOrc

If there are multiple instances of a particular parameter in these files, only the last one read will be stored. As a result of the directory ordering a local parameter setting will override the same parameter's global setting.

Parameters: \[ 0 = class \] , 1 = config file root (optional).

Return type: N/A.

### config\_param()

Retrieves named parameter value from configuration settings. Looks in configuration hash created by the 'read\_config\_files' method. If hash is empty it automatically runs that method to populate the hash. Note that this will use the default universal configuration file root. If your script needs to use a different configuration root, call 'read\_config\_files' explicitly -- if no argument is given it will default to using the calling script's name as root.

All parameter values are stored internally as arrays, even if there is only one value. This method will convert a return value to a scalar if there is only one value. If there are multiple values they will be returned as a list. For this reason it is important to know how parameter values are stored when using this method to retrieve them.

If no matching parameter is found then undef is returned.

Parameters: \[ 0 = class \] , 1 = param.

Return type: Scalar or List.

### uline()

Underline text.

Parameters: \[ 0 = class \] , 1 = string.

Return type: Scalar (string).

### number\_list()

Take list and prefix each element with element index. Index is left padded with spaces so each is the same length.

Example: 'Item' becomes ' 9. Item'.

Parameters: \[ 0 = class \] , 1 = list.

Return type: List.

### denumber\_list()

Take list and remove any number prefixes added with method 'number\_list'.

Example: ' 9. Item' becomes 'Item'.

Parameters: \[ 0 = class \] , 1 = list.

Return type: List.

### shorten()

Truncate text with ellipsis if too long.

Parameters: \[ 0 = class \] , 1 = string , 2 = limit ,
                            3 = continuation character (default: ellipsis).

Return type: Scalar (string).

### internet\_connection()

Checks to see whether an internet connection can be found. Checks connection to a number of sites supplied by libdncommon-vars.

Parameters: \[ 0 = class \].

Return type: Boolean.

### process\_fs\_mount\_file()

Reads mount file and stores information on mounted filesystems.

Credit: based on Linux::Mounts perl module by Stephane Chmielewski <snck@free.fr>.

Parameters: \[ 0 = class \] , 1 = mount\_file (optional).

Return type: N/A.

### cwd()

Provides current directory.

Uses 'getcwd' from package Cwd.

Parameters: \[ 0 = class \].

Return type: Scalar (dirpath).

### true\_path()

Converts relative to absolute filepaths. Any filepath can be provided to this method -- if an absolute filepath is provided it is returned unchanged. Symlinks will be followed and converted to their true filepaths.

If the directory part of the filepath does not exist the entire filepath is returned unchanged. This is a compromise. There may be times when you want to normalise a non-existent path, i.e, to collapse '../' parent directories. The 'abs\_path' function can handle a filepath with a nonexistent file. Unfortunately, however, it will silently return an empty result if an invalid directory is included in the path. Since safety should always take priority, the method will return the supplied filepath unchanged if the directory part does not exist.

WARNING: If passing a variable to this function it should be double quoted. If not, passing a value like './' results in an error as the value is somehow reduced to an empty value.

Parameters: \[ 0 = class \] , 1 = filepath , 2 = base (optional).

Return type: Scalar (filepath).

### mounted\_filesystems()

Returns list of mounted filesystems.

Will run 'process\_fs\_mount\_file' if this has not already occurred. Note that this method will be invoked without an argument so it will use the default mount file. If your script needs to use a different mount file, make sure to run 'process\_fs\_mount\_file' explicitly before calling 'get\_mounted\_filesystems'.

This method is based on an assumption that the mount file has at least one entry in it. On modern Linux systems that will always be true.

Credit: based on Linux::Mounts perl module by Stephane Chmielewski <snck@free.fr>.

Parameters: \[ 0 = class \].

Return type: List.

### filesystem\_mountpoint()

Determine mount point of filesystem.

Will run 'process\_fs\_mount\_file' if this has not already occurred. Note that this method will be invoked without an argument so it will use the default mount file. If your script needs to use a different mount file, make sure to run 'process\_fs\_mount\_file' explicitly before calling 'get\_mounted\_filesystems'.

This method is based on an assumption that the mount file has at least one entry in it. On modern Linux systems that will always be true.

Credit: based on Linux::Mounts perl module by Stephane Chmielewski <snck@free.fr>.

Parameters: \[ 0 = class \] , 1 = device node.

Return type: Scalar (path).

### pid\_running()

Determines whether process id is running.

A snapshot of the process list is captured into a table when this method is called for the first time. Any further invocations of this method then access the same table. To refresh the process table the method 'reload\_processes' must be called.

Parameters: \[ 0 = class \] , 1 = pid.

Return type: Scalar (boolean). (note: return value is actually the number of matching processes -- this is effectively a boolean value)

### process\_running()

Determines whether process is running. Matches on process command. Can match against part or all of process commands.

A snapshot of the process list is captured into a table when this method is called for the first time. Any further invocations of this method then access the same table. To refresh the process table the method 'reload\_processes' must be called.

Parameters: \[ 0 = class \] , 1 = command , 2 = match\_full\_cmd (optional, default = FALSE).

Return type: Scalar (boolean). (note: return value is actually the number of matching processes -- this is effectively a boolean value)

### reload\_processes()

Reloads/refreshes process table.

Parameters: \[ 0 = class \].

Return type: N/A.

### file\_mime\_type()

Get mime type of file.

Uses module File::MimeInfo.

Note: This method previously used File::Type and its 'mime\_type' method but that module incorrectly identifies some mp3 files as 'application/octet-stream'. If File::MimeInfo proves imperfect as well it may be necessary to use both. Other possible modules to use are File::MMagic and File::MMagic:Magic.

Parameters: \[ 0 = class \] , 1 = file name.

Return type: Scalar, undef on failure.

### is\_mp3()

Determine whether file is an mp3 file.

Note: This method previously used File::Type and its 'mime\_type' method but that module incorrectly identifies some mp3 files as 'application/octet-stream'. If File::MimeInfo proves imperfect as well it may be necessary to use both. Other possible modules to use are File::MMagic and File::MMagic:Magic.

Parameters: \[ 0 = class \] , 1 = file name.

Return type: Scalar, undef on failure.

### is\_mp4()

Determine whether file is an mp4 file.

Note: This method previously used File::Type and its 'mime\_type' method but that module incorrectly identifies some mp3 files as 'application/octet-stream'. If File::MimeInfo proves imperfect as well it may be necessary to use both. Other possible modules to use are File::MMagic and File::MMagic:Magic.

Parameters: \[ 0 = class \] , 1 = file name.

Return type: Scalar, undef on failure.

# NAME

Dn::CommonPerl - common methods for use by perl scripts

# SYNOPSIS

    use Dn::Common;

# DESCRIPTION

Provides methods used by Perl scripts. Can be used to create a standalone
object providing these methods; or as base class for derived module or class.

## method config\_params(parameter)

Uses Config::Simple.

### Configuration files syntax

This method can handle configuration files with the following formats:

> - simple
>
>         key1  value1
>         key2  value2
>
> - http-like
>
>         key1: value1
>         key2: value2
>
> - ini file
>
>         [block1]
>         key1=value1
>         key2=value2
>
>         [block2]
>         key3 = value3
>         key4 = value4
>
>     Note in this case the block headings are optional.

The key is provided as the argument to method, e.g.:
    $parameter1 = $cp->config\_param('key1');

If the ini file format is used with block headings, the block heading must be included using dot syntax, e.g.:
    $parameter1 = $cp->config\_param('block1.key1');

### Configuration file location and name

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

### Multiple values

A key can have multiple values separated by commas:

    key1  value1, value2, "value 3"

or

    key1: value1, value2

or

    key1=value1, value2

This is different to multiple **lines** in the configuration files defining the same key. In that case, the last such line overwrites all earlier ones.

### Return value

As it is possible to retrieve multiple values for a single key, this method uses a list variable internally to capture parameter values. If the method is returning its result in a list context, the list is returned. If the method is returning its result in a scalar context, the list is interpolated, e.g., "@values".

# DEPENDENCIES

These modules are not provided with Dn::Common.

## File::Util

Used for various file and directory operations, including recursive directory
creation and extracting filename and/or dirpath from a filepath.

Debian: provided by package 'libfile-util-perl'.

## File::Which

Used for finding paths to executable files.

Provides the 'which' function which mimics the bash 'which' utility.

Debian: provided by package 'libfile-which-perl'.

## File::Basename

Parse file names.

Provides the 'fileparse' method.

Debian: provided by package 'perl'.

## File::Copy

Used for file copying.

Provides the 'copy' and 'move' functions.

Debian: provided by package 'perl-modules'.

## Cwd

Used to normalise paths, including following symlinks and collapsing relative
paths. Also used to provide current working directory.

Provides the 'abs\_path' and 'getcwd' functions for these purposes,
respectively.

Debian: provided by package 'libfile-spec-perl'.

## File::MimeInfo

Provides 'mimetype' method for getting mime-type information about mp3 files.

Debian: provided by package 'libfile-mimeinfo-perl'.

Note: Previously used File::Type and its 'mime\_type' method to get file
mime-type information but that module incorrectly identifies some mp3 files as
'application/octet-stream'. Other alternatives are File::MMagic and
File::MMagic:Magic.

## Date::Simple

Used for writing date strings.

Debian: provided by package 'libdate-simple-perl'.

## Term::ANSIColor

Used for user input.

Provides the 'colored' function.

Debian: provided by package 'perl-modules'.

## Term::Clui

Used for user input.

Provides 'choose', 'ask', 'edit' and 'confirm' functions.

To prevent responses being remembered between invocations, include this command
after the use statement:

    $ENV{'CLUI_DIR'} = "OFF"; # do not remember responses

Debian: provided by package 'libperl-term-clui'.

## Text::Wrap

Used for formatting text into readable paragraphs.

Provides the 'wrap' function.

Debian: provided by package 'perl-base'.

## Storable

Used for storing and retrieving persistent data.

Provides the 'store' and 'retrieve' functions.

Debian: provided by package 'perl'.

## Config::Simple

Reads and parses configuration files.

Provides the 'import\_from' function.

Debian: provided by package 'libconfig-simple-perl'.

## Term::ReadKey

Used for reading single characters from keyboard.

Provides the ReadMode' and 'ReadKey' functions.

Debian: provided by package 'libterm-readkey-perl'.

## Net::Ping::External

Cross-platform interface to ICMP "ping" utilities. Enables the pinging of
internet hosts.

Provides the 'ping' function.

Debian: provided by package 'libnet-ping-external-perl'.

## Gtk2::Notify

Provides access to libnotify.

Provides the 'set\_timeout' and 'show' functions.

The module man page recommends the following nonstandard invocation:

    use Gtk2::Notify -init, "$0";

Debian: provided by package 'libgtk2-notify-perl'.

## Proc::ProcessTable

Provides access to system process table, i.e., output of 'ps'.

Provides the 'table' method.

Debian: provided by package 'libproc-processtable-perl'.

## Logger::Syslog

Interface to system log.

Provides functions 'debug', 'notice', 'warning' and 'error'.

Some system logs only record some message types. On debian systems, for
example, /var/log/messages records only 'notice' and 'warning' message types
while /var/log/syslog records all message types.

Debian: provided by package 'liblogger-syslog-perl'.

## Dn::Menu

Provides menus for use by Perl scripts. There are three kinds of menus
available: hotkey, terminal-based and graphical.

Debian: provided by package 'libdnmenu-perl'.

## Desktop::Detect

Detects running desktop.

Must export method 'detect\_desktop'.

## dncommon-vars bash library

Common variables used by bash and perl scripts.

Debian: provided by package 'libdncommon-vars'.

# AUTHOR

David Nebauer <davidnebauer@hotkey.net.au>

# COPYRIGHT

Copyright 2015- David Nebauer

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO
