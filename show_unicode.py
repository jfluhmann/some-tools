#!/usr/bin/env python3

import re
import sys
import unicodedata

filename = sys.argv[1]

with open(filename,'r', encoding='utf-8') as f:
    data=f.read()

DEBUG=False
#DEBUG=True
# Replace some knowns
# https://www.fileformat.info/info/unicode/block/general_punctuation/images.htm
if not DEBUG:
    data = data.replace(u"\u2019", "'").replace(u"\u2018", "'")           # Unicode Character 'RIGHT (U+2019) and LEFT (U+2018) SINGLE QUOTATION MARK'
    data = data.replace(u"\u201d", "\"").replace(u"\u2013", "\"")         # Unicode Character 'RIGHT DOUBLE QUOTATION MARK' (U+201D)
    #data = data.replace(u"replace(u"\u2013", "\"")                        # Unicode Character 'RIGHT DOUBLE QUOTATION MARK' (U+201D)
    data = data.replace(u"\u00Bd", "1/2")                                 # Unicode Character 'VULGAR FRACTION ONE HALF' (U+00BD)
#    data = data.replace(u"\u2013", "\"

data = data.replace("\x0C","")               # Form Feed or New Paper sheet

#print(data.encode('raw_unicode_escape'))

unicode_match = re.compile(r'(\\u[\w]{4})', re.IGNORECASE)
unicode_data = data.encode('raw_unicode_escape')

matches = unicode_match.findall(str(unicode_data))
for match in matches:
    character = match.encode('utf-8').decode('unicode_escape')
    try:
        character_name = unicodedata.name(character)
    except ValueError:
        character_name = 'no matching name'

    print("{}  {}    {}".format(match,character,character_name))


