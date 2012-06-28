#!/usr/bin/env python
"""Trimming of trailing white spaces.

Author-email: "Dietmar Winkler" <dietmarw at gmx de>

License: See UNLICENSE file

This script will recursively remove all trailing white spaces in all
text files in a given directory. Binary files and files residing in
'.svn' or '.git' directories are skipped.

It uses a binary tester based on the python magic implementation from
	Adam Hupp, http://hupp.org/adam/hg/python-magic

As a fallback (especially if libmagic is not available, like on Windows)
it acts only on files with a given file extension listed in 'extstring'.

"""
from __future__ import with_statement
import os
import sys
import textwrap

# For Windows: list of file extensions to apply the script on
# (including the dot and separated by a comma)
extstring = ".mo"

# list of version control directories to ignore
BLACKLIST = ['.bzr', '.cvs', '.git', '.hg', '.svn']

# convert the string object to a list object
listofexts  = extstring.split(",")

def usage(args):
	"""Help message on usage."""
	message = """
		Usage: %s [OPTIONS] <directory>

		 This script will recursively remove all trailing white spaces in all
		 text files in a given directory. Binary files and files residing in
		 '.bzr', '.cvs', '.git', '.hg', '.svn' directories are skipped.

		Note for Windows users:
		 If you have not libmagic installed the script will fallback to only
		 trim files with the following extensions: %s

		Options:
			-h, --help
				displays this help message
		""" % (os.path.split(args[0])[1],extstring,)
	print textwrap.dedent(message)

def unkownOption(args):
	"""Warning message for unknown options."""
	warning = """
		UNKNOWN OPTION: "%s"

		Use %s -h [--help] for usage instructions.
		""" % (args[1],args[0],)
	print textwrap.dedent(warning)

def detecttype(filepath):
	"""Look for *.mo extensions."""
	root, ext = os.path.splitext(filepath)
	if ext in listofexts:
		return "mo"
	else:
		return "unknown"

def main(args):
	import getopt
	# Look for optional arguments:
	try:
		opts, dirnames = getopt.getopt(args[1:], "h", ["help"])
	# Unknown option is given trigger the display message:
	except getopt.GetoptError:
		unkownOption(args)
		sys.exit(0)
	# if no dir name is given print the usage message
	if not dirnames:
		usage(args)
		sys.exit(0)

	# If help option is given display help otherwise display warning:
	for opt, arg in opts:
		if opt in ("-h","--help"):
			usage(args)
			sys.exit(0)
		else:
			unkownOption(args)
			sys.exit(0)

	# Walk through the given path and call trim function for text files only:
	for path, dirs, files in os.walk(args[1]):
		for file in files:
			filepath = os.path.join(path, file)
			filetype = detecttype(filepath)
			if blacklisted(path):
				print "skipping version control file: "+filepath
			elif filetype is "mo":
				print "Cleaning up " + filepath
				cleanCode(filepath)
			else:
				print "skipping file of type "+filetype+": "+filepath
def blacklisted(path):
	"""
	determines whether the given path contains a blacklisted directory
	"""
	for dirname in path.split(os.sep):
		if dirname in BLACKLIST:
			return True
	return False

def cleanCode(filepath):
	"""Clean out the obsolete or superflous code."""
	with open(filepath, 'r') as mo_file:
		string = mo_file[index_of("Window("):]
		depth = 0
		for char in string:
			if char == "(": depth += 1
			if char == ")": depth -= 1
			if depth == 0: last_index = current_char_position
	with open(filepath,'w') as mo_file:
		mo_file.write(string)

if __name__ == "__main__":
	sys.exit(main(sys.argv))
