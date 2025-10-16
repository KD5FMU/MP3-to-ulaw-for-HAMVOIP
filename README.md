# MP3-to-ulaw-for-HAMVOIP
Here is a hand script file thata will convert mp3 files to ulaw inside of HamVoIP
This script will randomly play a sound file on a node. The file must be in a format compatible with the
Asterisk software. The file name can contain no spaces. Using the _ in place of spaces is allowed.

1. Copy the random.sh file in this zip to your node in a directory of your choosing. We recommend
putting it in /usr/local/sbin..

2. Give it the required permission to be executed.

3. Create a folder to store your sound files. There can be no other files in this folder only sound
files compatible with Asterisk.

4. Place at least one sound file in the directory.

5. Call the random script. This can be done on the command line, crontab or from a dtmf in your
rpt.
Syntax : random.sh <sound file directory> <node to play on> <1 if global (optional)>
Examples
If you created a folder in the asterisk home directory called announce and placed sound files in it and
wanted to play them locally on node number 1234..
➢ random.sh /etc/asterisk/ announce 1234
Placing a 1 at the end would play it on ALL nodes this node is connected to. You would only want to do
this on a main hub you control and you don’t connect it to any other nodes. Only nodes connect in. We
don’t recommend you do this unless your sure it is ok.
➢ random.sh /etc/asterisk/ announce 1234 1
If you only put one file in the directory it will play that file every time the script is executed. Adding
files will randomly play one of the files when executed. It is possible that the script will play the same
file multiple times in a row if it happens to pick it that way. It is truly random. To stop a sound file from
playing simply remove it from the folder.
If you wanted to have a short sound play every 30 minutes you could add a crontab to accomplish this.
Using the example above..
➢ 30 * * * * /usr/local/sbin/random.sh /etc/asterisk/ announce 1234
