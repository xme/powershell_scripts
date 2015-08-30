#!/usr/bin/python
#
# Convert XML with hashes to CSV files
# Thanks to @ddurvaux for sharing!
#
import xml.etree.ElementTree as etree
import argparse
import base64

# configure arguments accepted by this script
parser = argparse.ArgumentParser(description='Process the XML output of Microsoft File Checksum Integrity Verifier (FCIV.exe).')
parser.add_argument('infile', nargs='+', help='XML file(s) that will be processed')
args = parser.parse_args()

# Loop on the files provided as argument
for filename in args.infile:
	try:
		root = etree.parse(filename).getroot()
		for n in zip(root.findall("FILE_ENTRY/name"), root.findall("FILE_ENTRY/MD5"), root.findall("FILE_ENTRY/SHA1")):
			name = n[0].text
			MD5 = base64.b64decode(n[1].text).encode("hex")
			SHA1 = base64.b64decode(n[2].text).encode("hex")
			print "%s, %s, %s" % (name, MD5, SHA1)
	except:
		print "FATAL ERROR while parsing %s" % (filename)
