#!/usr/bin/env python3

import re
import sys
import unicodedata

filename = sys.argv[1]

with open(filename,'r', encoding='utf-8') as f:
    data=f.read()

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


