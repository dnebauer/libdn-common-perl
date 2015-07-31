Dn::Common
==========

Provides useful methods for use by scripts.

Note that this module has been optimised for clarity of script rather than speed of execution. For example, it uses Mouse.

abort\( @messages, \[\$prepend\] \)
-----------------------------------

###Purpose

Display console message and abort script execution.

###Parameters

####@messages

Message lines. Respects newlines if enclosed in double quotes.

Required.

####\$prepend

Whether to prepend each message line with name of calling script.

Named parameter. Boolean.

Optional. Default: false.

###Prints

Messages followed by abort message.

###Returns

Nil.

###Usage

```perl
$cp->abort('We failed');
$cp->abort('We failed', prepend => 1);
```

adb_devices\(\)
---------------

###Purpose

Gets all attached adb devices.

###Parameters

Nil.

###Prints

Nil.

###Returns

List of device identifiers.

###Note

Tries to use 'fb-adb' then 'adb'. If neither is detected prints an error message and returns empty list (or undef if called in scalar context).

autoconf\_version\(\)
--------------

###Purpose

Gets autoconf version. Can be used as value for the autoconf macro 'AC_PREREQ'.

###Parameters

Nil.

###Prints

Nil on successful execution.

Error message on failure.

###Returns

Scalar string. Dies on failure.

backup\_file\(\$file\)
----------------------

###Purpose

Backs up file by renaming it to a unique file name. Will simply add integer to file basename.

###Parameters

####\$file

File to back up. 

Required.

###Prints

Nil.

###Returns

Scalar filename.

boolise\(\$value\)
------------------

###Purpose

Convert value to boolean.

Specifically, converts 'yes', 'true' and 'on' to 1, and convert 'no, 'false, and 'off' to 0. Other values are returned unchanged.

###Parameters

####\$value

Value to analyse.

Required.

###Prints

Nil.

###Returns

Boolean.

browse\( \$title, \$text \)
---------------------------

###Purpose

Displays large volume of text in default editor and then returns viewer to original screen.

###Parameters

####\$title

Title is prepended to displayed text \(along with some usage instructions\) and is used in creating the temporary file displayed in the editor.

Required.

####\$text

Text to display.

Required.

###Prints

Nil.

###Returns

Nil.

capture\_command\_output\(\$cmd\)
---------------------------------

###Purpose

Run system command and capture output.

###Parameters

####\$cmd

Command to run. Array reference.

Required.

###Prints

Nil.

###Returns

List: boolean success, list of stdout (success) or stdout + stderr (failure).

changelog\_from\_git\(\$dir\)
-----------------------------

###Purpose

Get ChangLog content from git repository.

###Parameters

####\$dir

Root file of repository. Must contain C<.git> subdirectory.

Required.

###Prints

Nil, except feedback on failure.

###Returns

List of scalar strings.

clear\_screen\(\)
-----------------

###Purpose

Clear the terminal screen.

###Parameters

Nil.

###Prints

Nil.

###Returns

Nil.

###Usage

```perl
$cp->clear_screen;
```

config\_param\(\$parameter\)
----------------------------

###Configuration file syntax

This method can handle configuration files with the following formats:

####simple

~~~~~~~~~~~~
key1  value1
key2  value2
~~~~~~~~~~~~

####http-like

~~~~~~~~~~~~
key1: value1
key2: value2
~~~~~~~~~~~~

####ini file

~~~~~~~~~~~~
[block1]
key1=value1
key2=value2

[block2]
key3 = value3
key4 = value4
~~~~~~~~~~~~

Note in this case the block headings are optional.

Warning: Mixing formats in the same file will cause a fatal error.

The key is provided as the argument to method, e.g.,

```perl
$parameter1 = $cp->config_param('key1');
```

If the ini file format is used with block headings, the block heading
must be included using dot syntax, e.g.,

```perl
$parameter1 = $cp->config_param('block1.key1');
```

###Configuration file locations and names

This method looks in these directories for configuration files in this order \(where FOO is the calling script\): ./, /usr/local/etc, /etc, /etc/FOO, and \$HOME.

Each directory is searched for these file names in this order \(where FOO is the calling script\): FOOconfig, FOOconf, FOO.config, FOO.conf, FOOrc, and .FOOrc.

###Multiple values

A key can have multiple values separated by commas:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
key1  value1, value2, "value 3"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

or

~~~~~~~~~~~~~~~~~~~~
key1: value1, value2
~~~~~~~~~~~~~~~~~~~~

or

~~~~~~~~~~~~~~~~~~~
key1=value1, value2
~~~~~~~~~~~~~~~~~~~

This is different to multiple lines in the configuration files defining the same key. In that case, the last such line overwrites all earlier ones.

###Return value

As it is possible to retrieve multiple values for a single key, this method returns a list of parameter values. If the result is obtained in scalar context it gives the number of values -- this can be used to confirm a single parameter result where only one is expected.

cwd\(\)
-------

###Purpose

Provides current directory.

###Parameters

Nil.

###Prints

Nil.

###Returns

Scalar string

date\_email\( \[\$date\], \[\$time\], \[\$offset\] \)
------------------------------------------------------

###Purpose

Produce a date formatted according to RFC 2822 (Internet Message Format). An example such date is 'Mon, 16 Jul 1979 16:45:20 +1000'.

###Parameters

####\$date

ISO-formatted date.

Named parameter. Optional. Default: today.

####\$time

A time in 24-hour format: 'HH:MM\[:SS\]'. Note that the following are not required: leading zero for hour, and seconds.

Named parameter. Optional. Default: now.

####\$offset

Timezone offset. Example: '+0930'.

Named parameter. Optional. Default: local timezone offset.

###Prints

Nil routinely. Error message if fatal error encountered.

###Returns

Scalar string, undef if method fails.

day\_of\_week\( \[\$date\] \)
-----------------------------

###Purpose

Get the day of week that the supplied date falls on.

###Parameters

####\$date

Date to analyse. Must be in ISO format.

Optional. Default: today.

###Prints

Nil.

###Returns

Scalar day name.

debian\_install\_deb\(\$deb\)
-----------------------------

###Purpose

Install debian package from a deb file.

First tries to install using C<dpkg> as if the user were root. If that fails, tries to install using C<sudo dpkg>. If that fails, finally tries to install using C<su -c dpkg>, which requires entry of the superuser (root) password.

###Parameters

####\$deb

Debian package file.

Required.

###Prints

Feedback.

###Returns

Scalar boolean.

debless\(\$object\)
-------------------

###Purpose

Get underlying data structure of object/blessed reference. Will only work on an object containing an underlying data structure that is a hash.

###Parameters

####\$object

Blessed reference to obtain underlying data structure of. Underlying data structure must be a hash.

Required.

###Prints

Nil, except error message if method fails.

###Returns

Hash. Dies if method fails.

deentitise\(\$string\)
----------------------

###Purpose

Perform standard conversions of HTML entities to reserved characters.

###Parameters

####\$string

String to analyse.

Required.

###Prints

Nil.

###Returns

Scalar string.

denumber\_list\(@list\)
-----------------------

###Purpose

Remove number prefixes added by method 'number\_list'.

###Parameters

####@items

List to modify.

Required.

###Prints

Nil.

###Return

List.

dir\_add\_dir\(\$dir, \$subdir\)
-------------------------------

###Purpose

Add subdirectory to directory path.

###Parameters

####\$dir

Directory path to add to. The directory need not exist.

Required.

####\$subdir

Subdirectory to add to path.

Required.

###Prints

Nil.

###Returns

Scalar directory path.

dir\_add\_file\(\$dir, \$file\)
-------------------------------

###Purpose

Add file name to directory path.

###Parameters

####\$dir

Directory path to add to. The directory need not exist.

Required.

####\$file

File name to add to path.

Required.

###Prints

Nil.

###Returns

Scalar file path.

dir\_split\(\$dir\)
-------------------

###Purpose

Split directory path into component subdirectories.

###Parameters

####\$dir

Directory path to split. Need not exist.

Required.

###Prints

Nil.

###Returns

List.

dirs\_list\( \[\$directory\] \)
-------------------------------

###Purpose

List subdirectories in directory. Uses current directory if no directory is supplied.

###Parameters

####\$directory

Directory from which to obtain file list.

Optional. Default: current directory.

###Prints

Nil \(error message if dies\).

###Returns

List \(dies if operation fails\).

display\(\$string\)
-------------------

###Purpose

Displays text on screen with word wrapping.

###Parameters

####\$string

Test for display.

Required.

###Print

Text for screen display.

###Return

Nil.

###Usage

```perl
$cp->display($long_string);
```

do\_copy\( \$src, \$dest \)
-----------------------

###Purpose

Copy source file or directory to target file or directory.

###Parameters

####\$src

Source file or directory. Must exist.

Required.

####\$dest

Destination file or directory. Need not exist.

Required.

###Prints

Nil on successful operation.

Error message on failure.

###Returns

Boolean success of copy operation.

Dies if missing argument.

###Notes

Can copy file to file or directory, and directory to directory, but not directory to file.

Uses the File::Copy::Recursive::rcopy function which tries very hard to complete the copy operation, including creating missing subdirectories in the target path.

do\_rmdir\(\$dir\)
------------------

###Purpose

Removes directory recursively (like 'rm -fr').

###Parameters

####\$dir

Root of directory tree to remove.

Required.

###Prints

Nil.

###Returns

Boolean scalar.

echo\_e\(\$string\)
-------------------

###Purpose

Use shell command 'echo -e' to display text in console. Escape sequences are escaped.

###Parameters

####\$text

Text to display. Scalar string.

Required.

###Prints

Text with shell escape sequences escaped.

###Returns

Nil.

echo\_en\(\$string\)
--------------------

###Purpose

Use shell command 'echo -en' to display text in console. Escape sequences are escaped. No newline is appended.

###Parameters

####\$text

Text to display. Scalar string.

Required.

###Prints

Text with shell escape sequences escaped and no trailing newline.

###Returns

Nil.

ensure\_no\_trailing\_slash\(\$dir\)
------------------------------------

###Purpose

Remove trailing slash \('/'\), if present, from directory path.

###Parameters

####\$dir

Directory path to analyse.

Required.

###Prints

Nil.

###Returns

Scalar string (directory path).

Undef if no directory path provided.

ensure\_trailing\_slash\(\$dir\)
--------------------------------

###Purpose

Ensure directory has a trailing slash \('/'\).

###Parameters

=over

####\$dir

Directory path to analyse.

Required.

###Prints

Nil.

###Returns

Scalar string \(directory path\).

Undef if no directory path provided.

entitise\(\$string\)
--------------------

###Purpose

Perform standard conversions of reserved characters to HTML entities.

###Parameters

####\$string

String to analyse.

Required.

###Prints

Nil.

###Returns

Scalar string.

executable\_path\(\$exe\)
-------------------------

###Purpose

Get path of executable.

###Parameters

####\$exe

Short name of executable.

Required.

###Prints

Nil.

###Return

Scalar filepath: absolute path to executable if executable exists.

Scalar boolean: returns undef If executable does not exist.

extract\_key\_value\( \$key, @items \)
--------------------------------------

###Purpose

Provided with a list that contains a key-value pair as a sequential pair of elements, return the value and the list-minus-key-and-value.

###Parameters

####\$key

Key of the key-value pair.

Required.

####@items

The items containing key and value.

Required.

###Prints

Nil.

###Returns

List with first element being the target value \(undef if not found\) and subsequent elements being the original list minus key and value.

###Usage

```perl
my ($value, @list) = $cp->($key, @list);
```

files\_list\( \[\$directory\] \)
--------------------------------

###Purpose

List files in directory. Uses current directory if no directory is supplied.

###Parameters

####\$directory

Directory path.

Optional. Default: current directory.

###Prints

Nil.

###Returns

List. Dies if operation fails.

find\_files\_in\_dir\( \$dir, \$pattern \)
------------------------------------------

###Purpose

Finds file in directory matching a given pattern. Note that only the nominated directory is searched -- the search does not recurse into subdirectories.

###Parameters

####\$dir

Directory to search.

Required.

####\$pattern

File name pattern to match. It can be a glob or a regular expression.

Required.

###Prints

Nil.

###Returns

List of absolute file paths.

future\_date\(\$date\)
----------------------

###Purpose

Determine whether supplied date occurs in the future, i.e, today or after today.

###Parameters

####\$date

Date to compare. Must be ISO format.

Required.

###Prints

Nil. \(Error if invalid date.\)

###Return

Boolean. \(Dies if invalid date.\)

get\_filename\(\$filepath\)
---------------------------

###Purpose

Get filename from filepath.

###Parameters

####\$filepath

Filepath to analyse. Assumed to have a filename as the last element in the path.

Required.

###Prints

Nil.

###Returns

Scalar string \(filename\).

###Note

This method simply returns the last element in the path. If it is a directory path, and there is no trailing directory separator, the final subdirectory in the path is returned. It is potentially possible to check the path at runtime to determine whether it is a directory path or file path. The disadvantage of doing so is that the method would then not be able to handle "virtual" filepaths.

get\_path\(\$filepath\)
-----------------------

###Purpose

Get path from filepath.

###Parameters

####\$filepath

File path.

Required.

###Prints

Nil.

###Returns

Scalar path.

input\_ask\( \$prompt, \[\$default\], \[\$prepend\] \)
------------------------------------------------------

###Purpose

Obtain input from user.

This method is intended for entering short values. Once the entered text wraps to a new line the user cannot move the cursor back to the previous line.

Use method 'input\_large' if the value is likely to be longer than a single line.

###Parameters

####\$prompt

User prompt. If user uses 'prepend' option \(see below\) the script name is prepended to the prompt.

####\$default

Default input.

Optional. Default: none.

####\$prepend

Whether to prepend the script name to the prompt.

Named parameter. Boolean.

Optional. Default: false.

###Prints

User interaction.

###Returns

User's input \(scalar\).

###Usage

```perl
my $value;
my $default = 'default';
while (1) {
    $value = $self->input_ask( "Enter value:", $default );
    last if $value;
}
```

input\_choose\( \$prompt, @options, \[\$prepend\] \)
----------------------------------------------------

###Purpose

User selects option from a menu.

###Parameters

####\$prompt

Menu prompt.

Required.

####@options

Menu options.

Required.

####\$prepend

Flag indicating whether to prepend script name to prompt.

Named parameter. Scalar boolean.

Optional. Default: false.

###Prints

Menu and user interaction.

###Returns

Return value depends on the calling context:

####scalar

Returns scalar \(undef if choice cancelled\).

####list

Returns list \(empty list if choice cancelled\).

###Usage

```perl
my $value = undef;
my @options = ( 'Pick me', 'No, me!' );
while (1) {
    $value = $self->input_choose( "Select value:", @options );
    last if $value;
    say "Invalid choice. Sorry, please try again.";
}
```

input\_confirm\( \$question, \[\$prepend\] \)
---------------------------------------------

###Purpose

User answers y/n to a question.

###Parameters

####\$question

Question to elicit user response. If user uses 'prepend' option \(see below\) the script name is prepended to it.

Can be multi-line, i.e., enclose in double quotes and include '\\n' newlines. After the user answers, all but first line of question is removed from the screen. For that reason, it is good style to make the first line of the question a short summary, and subsequent lines can give additional detail.

Required.

####\$prepend

Whether to prepend the script name to the question.

Boolean.

Optional. Default: false.

###Prints

User interaction.

###Return

Scalar boolean.

###Usage

```perl
my $prompt = "Short question?nnMorenmulti-linentext.";
if ( input_confirm($prompt) ) {
    # do stuff
}
```

input\_large\( \$prompt, \[\$default\], \[\$prepend\] \)
--------------------------------------------------------

###Purpose

Obtain input from user.

This method is intended for entry of data likely to be longer than a single line. Use method 'input\_ask' if entering a simple \(short\) value. An editor is used to enter the data. The default editor is used. If no default editor is set, vi\(m\) is used.

When the editor opens it displays some boilerplate, the prompt, a horizontal rule \(a line of dashes\), and the default value if provided. When the editor is closed all lines up to and including the first horizontal rule are deleted. The user can get the same effect by deleting in the editor all lines up to and including the first horizontal rule.

Use method 'input\_ask' if the prompt and input will fit on a single line.

###Parameters

####\$prompt

User prompt. If user uses 'prepend' option \(see below\) the script name is prepended to the prompt.

####\$default

Default input.

Optional. Default: none.

####\$prepend

Whether to prepend the script name to the prompt.

Named parameter. Boolean.

Optional. Default: false.

###Prints

User interaction.

###Returns

User's input as list, split on newlines in user input.

###Usage

Here is a case where input is required:

```perl
my @input;
my $default = 'default';
my $prompt = 'Enter input:';
while (1) {
    @input = $self->input_large( $prompt, $default );
    last if @input;
    $prompt = "Input is requirednEnter input:";
}
```

internet\_connection\(\)
------------------------

###Purpose

Checks to see whether an internet connection can be found.

###Parameters

Nil.

###Prints

Nil.

###Returns

Boolean.

is\_boolean\(\$value\)
----------------------

###Purpose

Determine whether supplied value is boolean.

Specifically, checks whether value is one of: 'yes', 'true', 'on', 1, 'no, 'false, 'off' or 0.

###Parameters

####\$value

Value to be analysed.

Required.

###Prints

Nil.

###Returns

Boolean. \(Undefined if no value provided.\)

###is\_mp3\(\$filepath\)

###Purpose

Determine whether file is an mp3 file.

###Parameters

####\$filepath

File to analyse.

Required. Method dies if \$filepath is not provided or is invalid.

###Prints

Nil.

###Returns

Scalar boolean.

###is\_mp4\(\$filepath\)

###Purpose

Determine whether file is an mp4 file.

###Parameters

####\$filepath

File to analyse.

Required. Method dies if \$filepath is not provided or is invalid.

###Prints

Nil.

###Returns

Scalar boolean.

is\_mp3\(\$filepath\)
---------------------

###Purpose

Determine whether file is an mp3 file.

###Parameters

####\$filepath

File to analyse.

Required. Method dies if \$filepath is not provided or is invalid.

###Prints

Nil.

###Returns

Scalar boolean.

is\_mp4\(\$filepath\)
---------------------

###Purpose

Determine whether file is an mp4 file.

###Parameters

####\$filepath

File to analyse.

Required. Method dies if \$filepath is not provided or is invalid.

###Prints

Nil.

###Returns

Scalar boolean.

is\_perl\(\$filepath\)
----------------------

###Purpose

Determine whether file is a perl file.

###Parameters

####\$filepath

File to analyse.

Required. Method dies if \$filepath is not provided or is invalid.

###Prints

Nil.

###Returns

Scalar boolean.

join\_dir\(\$dir\)
------------------

###Purpose

Concatenate list of directories in path to string path.

###Parameters

####\$dir

Directory parts. Array reference.

Required.

###Prints

Nil.

###Returns

Scalar string directory path. (Dies on error.

konsolekalendar\_date\_format\( \[\$date\] \)
---------------------------------------------

###Purpose

Get date formatted in same manner as konsolekalendar does in its output. An example date value is 'Tues, 15 Apr 2008'. The corresponding strftime format string is '%a, %e %b %Y'.

###Parameters

####\$date

Date to convert. Must be in ISO format.

Optional, Default: today.

###Prints

Nil.

###Returns

Scalar date string.

listify\(@items\)
-----------------

###Purpose

Tries to convert scalar, array and hash references in list to sequences of simple scalars. For other reference types a warning is issued.

###Parameters

####@items

Items to convert to simple list.

###Prints

Warning messages for references other than scalar, array and hash.

###Returns

Simple list.

local\_timezone\(\)
-------------------

###Purpose

Get local timezone.

###Parameters

Nil.

###Prints

Nil.

###Returns

Scalar string.

logger\( \$message, \[\$type\] \)
---------------------------------

###Purpose

Display message in system log.

There are four message types: 'debug', 'notice', 'warning' and 'error'. Not all message types appear in all system logs. On Debian, for example, /var/log/messages records only notice and warning log messages while /var/log/syslog records all log messages.

Method dies if invalid message type is provided.

###Parameters

####\$message

Message content.

Required.

####\$type

Type of log message. Must be one of 'debug', 'notice', 'warning' and 'error'.

Method dies if invalid message type is provided.

Optional. Default: 'notice'.

###Prints

Nil.

###Returns

Nil. Note method dies if invalid message type is provided.

###Usage

```perl
$cp->logger('Widget started');
$cp->logger( 'Widget died unexpectedly!', 'error' );
```

make\_dir\(\$dir\_path\)
------------------------

###Purpose

Make directory recursively.

###Parameters

####\$dir\_path

Directory path to create.

Required.

###Prints

Nil.

###Return

Scalar boolean. If directory already exists returns true.

msg\_box\( \[\$msg\], \[\$title\] \)
------------------------------------

###Purpose

Display message in gui message box.

###Parameters

####\$msg

Message to display.

Optional. Default: 'Press OK button to proceed'.

####\$title

Title of message box.

Optional. Default: name of calling script.

###Prints

Nil.

###Returns

N/A.

notify\( @messages, \[\$prepend\] \)
------------------------------------

###Purpose

Display console message.

###Parameters

####@messages

Message lines. Respects newlines if enclosed in double quotes.

Required.

####\$prepend

Whether to prepend each message line with name of calling script.

Named parameter. Boolean.

Optional. Default: false.

###Prints

Messages.

###Returns

Nil.

###Usage

```perl
$cp->notify('File path is:', $filepath);
$cp->notify('File path is:', $filepath, prepend => 1);
```

notify\_sys\_type\(\$type\)
---------------------------

notify\_sys\_title\(\$title\)
-----------------------------

notify\_sys\_icon\(\$icon\)
---------------------------

###Purpose

Set default values for 'notify\_sys' method parameters 'type', 'title' and 'icon', respectively. Applies to subsequent calls to 'notify\_sys'. Overridden by parameters supplied in subsequent 'notify\_sys' method calls.

notify\_sys\( \$message, \[\$title\], \[\$type\], \[\$icon\], \[\$time\] \)
---------------------------------------------------------------------------

###Purpose

Display message to user in system notification area

###Parameters

####\$message

Message content.

Note there is no guarantee that newlines in message content will be respected.

Required.

####\$title

Message title.

Named parameter. Optional. Default: name of calling script.

####\$type

Type of message. Must be one of 'info', 'question', 'warn' and 'error'.

Named parameter. Optional. Default: 'info'.

####\$icon

Message box icon filepath.

Named parameter. Optional. A default icon is provided for each message type.

####\$time

Message display time \(msec\).

Named parameter. Optional. Default: 10,000.

###Prints

Nil.

###Returns

Boolean: whether able to display notification.

###Usage

```perl
$cp->notify_sys('Operation successful!', title => 'Outcome')
```

###Caution

Do not call this method from a spawned child process -- the 'show\(\)' call in the last line of this method causes the child process to hang without any feedback to user.

now\(\)
-------

###Purpose

Provide current time in format 'HH::MM::SS'.

###Parameters

Nil.

###Prints

Nil.

###Returns

Scalar string.

number\_list\(@items\)
----------------------

###Purpose

Prefix each list item with element index. The index base is 1.

The prefix is left padded with spaces so each is the same length.

Example: 'Item' becomes ' 9. Item'.

###Parameters

####@items

List to be modified.

Required.

###Prints

Nil.

###Returns

List.

offset\_date\(\$offset\)
------------------------

###Purpose

Get a date offset from today. The offset can be positive or negative.

###Parameters

####\$offset

Offset in days. Can be positive or negative.

Required.

###Prints

Nil.

###Returns

ISO-formatted date.

pid\_running\(\$pid\)
---------------------

###Purpose

Determines whether process id is running.

###Parameters

####\$pid

Process ID to search for.

Required.

###Prints

Nil.

###Returns

Boolean scalar.

pluralise\( \$string, \$number \)
---------------------------------

###Purpose

Adjust string based on provided numerical value. Note that this method is a simple wrapper of Text::Pluralize::pluralize.

###Parameters

####\$string

String to adjust based on the numeric value provided.

Required.

####\$number

Numeric value used in adjusting the string provided. Must be a positive integer (including zero).

Required.

###Prints

Nil.

###Returns

Scalar string.

process\_running\( \$cmd, \[\$match\_full\] \)
----------------------------------------------

###Purpose

Determines whether process is running. Matches on process command. Can match against part or all of process commands.

###Parameters

####\$cmd

Command to search for.

Required.

####\$match\_full

Whether to require match against entire process command.

Optional. Default: false.

###Prints

Nil.

###Returns

Boolean scalar.

prompt\( \[message\] \)
-----------------------

###Purpose

Display message and prompt user to press any key.

###Parameters

####Message

Message to display.

Optional. Default: 'Press any key to continue'.

###Prints

Message.

###Returns

Nil.

restore\_screensaver\( \[\$title\] \)
-------------------------------------

###Purpose

Restore suspended kde screensaver.

Only works if used by the same process that suspended the screensaver \(See method "suspend\_screensaver". The screensaver is restored automatically is the process that suspended the screensaver exits.

###Parameters

####\$title

Message box title. Note that feedback is given in a popup notification \(see method "notify\_sys"\).

Optional. Default: name of calling script.

###Prints

User feedback indicating success or failure.

###Returns

Boolean. Whether able to successfully suspend the screensaver.

retrieve\_store\(\$file\)
-------------------------

###Purpose

Retrieves function data from storage file.

###Parameters

####\$file

File in which data is stored.

Required.

###Prints

Nil \(except feedback from Storage module\).

###Returns

Boolean.

###Usage

```perl
my $storage_file = '/path/to/filename';
my $ref = $self->retrieve_store($storage_file);
my %data = %{$ref};
```

save\_store\( \$ref, \$file \)
------------------------------

###Purpose

Store data structure in file.

###Parameters

####\$ref

Reference to data structure \(usually hash or array\) to be stored.

####\$file

File path in which to store data.

###Prints

Nil \(except feedback from Storable module\).

###Returns

Boolean.

###Usage

```perl
my $storage_dir = '/path/to/filename';
$self->save_store( %data, $storage_file );
```

scriptname\(\)
--------------

###Purpose

Get name of executing script.

###Parameters

Nil.

###Prints

Nil.

###Returns

Scalar string.

sequential\_24h\_times\( \$time1, \$time2 \)
--------------------------------------------

###Purpose

Determine whether supplied times are in chronological sequence, i.e., second time occurs after first time. Assume both times are from the same day.

###Parameters

####\$time1

First time to compare. 24 hour time format.

Required.

####\$time2

Second time to compare. 24 hour time format.

Required.

###Prints

Nil. \(Error if invalid time.\)

###Returns

Boolean \(Dies if invalid time.\)

sequential\_dates\( \$date1, \$date2 \)
---------------------------------------

###Purpose

Determine whether supplied dates are in chronological sequence.

Both dates must be in ISO format or method will return failure. It is recommended that date formats be checked before calling this method.

###Parameters

####\$date1

First date. ISO format.

Required.

####\$date2

Second date. ISO format.

Required.

###Prints

Nil. Error message if dates not in ISO-format.

###Returns

Boolean.

shared\_module\_file\_milla\( \$dist, \$file \)
-----------------------------------------------

###Purpose

Obtains the path to a file in a module's shared directory. Assumes the module was built using dist-milla and the target file was in the build tree's 'share' directory.

###Parameters

####\$dist

Module name. Uses "dash" format. For example, module My::Module would be 'My-Module'.

Required.

####\$file

Name of file to search for.

Required.

###Prints

Nil.

###Returns

Scalar. (If not found returns undef, so can also function as scalar boolean.)

shell\_underline\(\$string\)
----------------------------

###Purpose

Underline string using shell escapes.

###Parameters

####\$string

String to underline. Scalar string.

Required.

###Prints

Nil.

###Returns

Scalar string: string with enclosing shell commands.

shorten\( \$string, \[\$limit\], \[\$cont\] \)
----------------------------------------------

###Purpose

Truncate text with ellipsis if too long.

###Parameters

####\$string

String to shorten.

Required.

####\$length

Length at which to truncate. Must be integer > 10.

Optional. Default: 72.

####\$cont

Continuation sequence placed at end of truncated string to indicate shortening. Cannot be longer than three characters.

Optional. Default: '...'.

###Prints

Nil.

###Returns

Scalar string.

suspend\_screensaver\( \[\$title\], \[\$msg\] \)
------------------------------------------------

###Purpose

Suspend kde screensaver if it is present.

The screensaver is suspended until it is restored \(see method "restore\_screensaver"\) or the process that suspended the screensaver exits.

###Parameters

####\$title

Message box title. Note that feedback is given in a popup notification \(see method "notify\_sys"\).

Optional. Default: name of calling script.

####\$msg

Message explaining suspend request. It is passed to the screensaver object and is not seen by the user.

Named parameter.

Optional. Default: 'request from \$PID'.

###Prints

User feedback indicating success or failure.

###Returns

Boolean. Whether able to successfully suspend the screensaver.

###Usage

```perl
$cp->suspend_screensaver('Playing movie');
$cp->suspend_screensaver(
    'Playing movie', msg => 'requested by my-movie-player'

);
```

tabify\( \$string, \[\$tab\_size\] \)
-------------------------------------

###Purpose

Covert tab markers \('\t'\) in string to spaces. Default tab size is four spaces.

###Parameters

####\$string

String in which to convert tabs.

Required.

####\$tab\_size

Number of spaces in each tab. Integer.

Optional. Default: 4.

###Prints

Nil.

###Returns

Scalar string.

timezone\_from\_offset\(\$offset\)
----------------------------------

###Purpose

Determine timezone for offset. In most cases an offset matches multiple timezones. The first matching Australian timezone is selected if one is present, otherwise the first matching timezone is selected.

###Parameters

####\$offset

Timezone offset to check. Example: '+0930'.

Required.

###Prints

Error message if no offset provided or no matching timezone found.

###Returns

Scalar string \(timezone\), undef if no match found.

today\(\)
---------

###Purpose

Get today as an ISO-formatted date.

###Parameters

Nil.

###Prints

Nil.

###Returns

ISO-formatted date.

trim\(\$string\)
----------------

###Purpose

Remove leading and trailing whitespace.

###Parameters

####\$string

String to be converted.

Required.

###Prints

Nil.

###Returns

Scalar string.

true\_path\(\$filepath\)
------------------------

###Purpose

Converts relative to absolute filepaths. Any filepath can be provided to this method -- if an absolute filepath is provided it is returned unchanged. Symlinks will be followed and converted to their true filepaths.

If the directory part of the filepath does not exist the entire filepath is returned unchanged. This is a compromise. There may be times when you want to normalise a non-existent path, i.e, to collapse '../' parent directories. The 'abs\_path' function can handle a filepath with a nonexistent file. Unfortunately, however, it will silently return an empty result if an invalid directory is included in the path. Since safety should always take priority, the method will return the supplied filepath unchanged if the directory part does not exist.

WARNING: If passing a variable to this function it should be double quoted. If not, passing a value like './' results in an error as the value is somehow reduced to an empty value.

###Parameters

####\$filepath

Path to analyse. If a variable should be double quoted \(see above\).

Required.

###Prints

Nil

###Returns

Scalar filepath.

valid\_24h\_time\(\$time\)
--------------------------

###Purpose

Determine whether supplied time is valid.

###Parameters

####\$time

Time to evaluate. Must be in 'HH::MM' format \(leading zero can be dropped\).

Required.

###Prints

Nil.

###Returns

Boolean.

valid\_date\(\$date\)
---------------------

###Purpose

Determine whether date is valid and in ISO format.

###Parameters

####\$date

Candidate date.

Required.

###Prints

Nil.

###Returns

Boolean.

valid\_email(\$email\)
----------------------

###Purpose

Determine validity of an email address.

###Parameters

####\$email

Email address to validate.

Required.

###Prints

Nil.

###Return

Scalar boolean.

valid\_integer\(\$value\)
-------------------------

###Purpose

Determine whether supplied value is a valid integer.

###Parameters

####\$value

Value to test.

Required.

###Prints

Nil.

###Returns

Boolean.

valid\_positive\_integer\(\$value\)
-----------------------------------

###Purpose

Determine whether supplied value is a valid positive integer \(zero or above\).

###Parameters

####\$value

Value to test.

Required.

###Prints

Nil.

###Returns

Boolean.

valid\_web\_uri(\$email\)
-------------------------

###Purpose

Determine validity of a web URI.

###Parameters

####\$uri

Web address to validate.

Required.

###Prints

Nil.

###Return

Scalar boolean.

valid\_timezone\_offset\(\$offset\)
-----------------------------------

###Purpose

Determine whether a timezone offset is valid.

###Parameters

####\$offset

Timezone offset to analyse. Example: '+0930'.

Required.

###Prints

Nil.

###Returns

Scalar boolean.

vim\_list\_print\(@messages\)
-----------------------------

###Purpose

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

###Parameters

####@messages

Each element of the list can be printed in a different style.  Element strings need to be prepared using the 'vim\_printify' method. See the 'vim\_printify' method for an example.

Required.

###Prints

Messages in requested styles.

###Returns

Nil.

vim\_print\( \$type, @messages \)
---------------------------------

###Purpose

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


###Parameters

####\$type

Type of text. Determines colour scheme.

Must be one of: 'title', 'error', 'warning', 'prompt' and 'normal'. Case-insensitive. Can supply a partial value, down to and including just the first letter.

Required.

####@messages

Content to display.

Supplied strings can contain escaped double quotes.

Required.

###Prints

Messages in the requested colour scheme.

###Returns

Nil.

###Usage

```perl
$cp->vim_print( 't', 'This is a title' );
```

vim\_printify\( \$type, \$message \)
------------------------------------

###Purpose

Modifies a single string to be included in a List to be passed to the 'vim\_list\_print' method. The string is given a prefix that signals to 'vim\_list\_print' what format to use. The prefix is stripped before the string is printed.

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


###Parameters

####\$type

Type of text. Determines colour scheme.

Must be one of: 'title', 'error', 'warning', 'prompt' and 'normal'. Case-insensitive. Can supply a partial value, down to and including just the first letter.

Required.

####\$message

Content to modify.

Supplied string can contain escaped double quotes.

Required.

###Prints

Nil.

###Returns

Modified string.

###Usage

```perl
$cp->vim_printify( 't', 'This is a title' );
```

Dependencies
============

autodie
-------

Automated error checking of 'open' and 'close' functions.

Debian: provided by package 'libautodie-perl'.

Carp
----

Modern error handling.

Debian: provided by package 'perl-base'.

Config::Simple
--------------

Reads and parses configuration files.

Provides the 'import\_from' function.

Debian: provided by package 'libconfig-simple-perl'.

Curses
------

Terminal screen handlind.

Cwd
---

Used to normalise paths, including following symlinks and collapsing relative paths. Also used to provide current working directory.

Provides the 'abs\_path' and 'getcwd' functions for these purposes, respectively.

Debian: provided by package 'libfile-spec-perl'.

Data::Dumper::Simple
--------------------

Used for displaying variables.

Debian: provided by package 'libdata-dumper-simple-perl'.

Data::Validate::URI
-------------------

Used for validating web URIs.

Debian: Provided by 'libdata-validate-uri-perl'.

Date::Simple
------------

Used for writing date strings.

Debian: provided by package 'libdate-simple-perl'.

DateTime
--------

DateTime::Format::Mail
----------------------

DateTime::TimeZone
------------------

Used for manipulating dates and times.

Debian: provided by packages 'libdatetime-perl', 'libdatetime-format-mail-perl' and 'libdatetime-timezone-perl', respectively.

Desktop::Detect
---------------

Used for detecting KDE desktop. Uses 'detect\_desktop' function.

Debian: provided by package 'libdesktop-detect-perl'.

Email::Valid
------------

Used for validating email addresses.

Debian: provided by package 'libemail-valid-perl'.

Env
---

Import environmental variables.

Debian: provided by package 'perl-modules'.

File::Basename
--------------

Parse file names.

Provides the 'fileparse' method.

Debian: provided by package 'perl'.

File::chdir
-----------

Provides $CWD and @CWD for manipulating current directory.

Debian: provided by package 'libfile-chdir-perl'.

File::Copy
----------

Used for file copying.

Provides the 'copy' and 'move' functions.

Debian: provided by package 'perl-modules'.

File::Find::Rule
----------------

Enables searching for files and directories.

Debian: provided by package 'libfile-find-rule-perl'.

File::MimeInfo
--------------

Provides 'mimetype' method for getting mime-type information about mp3 files.

Debian: provided by package 'libfile-mimeinfo-perl'.

Note: Previously used File::Type and its 'mime\_type' method to get file mime-type information but that module incorrectly identifies some mp3 files as 'application/octet-stream'. Other alternatives are File::MMagic and File::MMagic:Magic.

File::Spec
----------

Perform operations on file and directory names.

Debian: provided by package 'perl-base'.

File::Util
----------

Used for various file and directory operations, including recursive directory creation and extracting filename and/or dirpath from a filepath.

Debian: provided by package 'libfile-util-perl'.

File::Which
-----------

Used for finding paths to executable files.

Provides the 'which' function which mimics the bash 'which' utility.

Debian: provided by package 'libfile-which-perl'.

Function::Parameters
--------------------

Enables use of modern method interface.

Debian: provided by package 'libfunction-parameters-perl',

Gtk2::Notify
------------

Provides access to libnotify.

Provides the 'set\_timeout' and 'show' functions.

Uses this nonstandard invocation recommended by the module man page:

####use Gtk2::Notify -init, "\$0";

Debian: provided by package 'libgtk2-notify-perl'.

HTML::Entities
--------------

Used for converting between html entities and reserved characters. Provides 'encode\_entities' and 'decode\_entities' methods.

Debian: provided by package: 'libhtml-parser-perl'.

Debian: provided by package 'libnet-ping-external-perl'.

IPC::Cmd
--------

IPC::Open3
----------

IPC::Run
--------

Enable running of system commands.

Debian: provided by packages 'perl-modules', 'libipc-run-perl' and 'perl-base', respectively.

Logger::Syslog
--------------

Interface to system log.

Provides functions 'debug', 'notice', 'warning' and 'error'.

Some system logs only record some message types. On debian systems, for example, /var/log/messages records only 'notice' and 'warning' message types while /var/log/syslog records all message types.

Debian: provided by package 'liblogger-syslog-perl'.

namespace::autoclean
--------------------

Used to optimise Mouse.

Debian: provided by package 'libnamespace::autoclean'.

Mouse
-----

Use modern perl.

Debian: provided by 'libmouse-perl'.

Mouse::Util::TypeConstraints
----------------------------

Used to enhance Mouse.

Debian: provided by 'libmouse-perl'.

MouseX::NativeTraits
--------------------

Used to enhance Mouse.

Debian: provided by package 'libmousex-nativetraits-perl'.

Net::DBus
---------

Used in manipulating DBus services.

Debian: provided by package 'libnet-dbus-perl'.

Net::Ping::External
-------------------

Cross-platform interface to ICMP "ping" utilities. Enables the pinging of internet hosts.

Provides the 'ping' function.

Proc::ProcessTable
------------------

Provides access to system process table, i.e., output of 'ps'.

Provides the 'table' method.

Debian: provided by package 'libproc-processtable-perl'.

Readonly
--------

Use modern perl.

Debian: provided by package 'libreadonly-perl'

Storable
--------

Used for storing and retrieving persistent data.

Provides the 'store' and 'retrieve' functions.

Debian: provided by package 'perl'.

Term::ANSIColor
---------------

Used for user input.

Provides the 'colored' function.

Debian: provided by package 'perl-modules'.

Term::Clui
----------

Used for user input.

Provides 'choose', 'ask', 'edit' and 'confirm' functions.

Is configured to not remember responses. To override put this command after this module is called:

```perl
$ENV{'CLUI_DIR'} = "ON";
```

Debian: provided by package 'libperl-term-clui'.

Term::ReadKey
-------------

Used for reading single characters from keyboard.

Provides the 'ReadMode' and 'ReadKey' functions.

Debian: provided by package 'libterm-readkey-perl'.

Test::NeedsDisplay
------------------

Prevents build error caused by Gtk2::Notify. The module tests require a display but cannot find one. Test::NeedsDisplay provides a fake display.

Debian: provided by package 'libtest-needsdisplay-perl'.

Text::Wrap
----------

Used for formatting text into readable paragraphs.

Provides the 'wrap' function.

Debian: provided by package 'perl-base'.

Time::Simple
------------

Used for validating and comparing times. May be distributed with this module.

Debian: not available from offial repositories, but available in local debian package of this module.

UI::Dialog
----------

Used for gui dialogs.

Debian: provided by package 'libui-dialog-perl'.

License
=======

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
