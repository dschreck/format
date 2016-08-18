/*
 * format - haXe File Formats
 *
 * Copyright (c) 2008, The haXe Project Contributors
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package format.amf3;
import format.amf3.Value;

class Reader {
	
	public static inline var INT_MAX_VALUE = 2147483647;

	var i : haxe.io.BytesInput;

	var stringTable:Array<String> = new Array<String>();
	var objectTable:Array<Dynamic> = new Array<Dynamic>();
	var traitTable:Array<Dynamic> = new Array<Dynamic>();

	public function new( i : haxe.io.BytesInput ) {
		this.i = i;
		i.bigEndian = true;
	}

	function readObject() {
		var n = readInt();
		
		if ((n & 1) == 0) {
			return getTableEntry(objectTable, n >> 1);
		}

		var dyn = ((n >> 3) & 0x01) == 1;
		n >>= 4;
		i.readByte();
		var h = new Map();
		if (dyn) {
			var s;
			while ( true ) {
				s = readString();
				if (s == "") break;
				h.set(s, read());
			}
		}
		else {
			var a = new Array();
			for (j in 0...n)
				a.push(readString());
			for (j in 0...n)
				h.set(a[j], read());
		}
		return h;
	}
	
	function readMap(n : Int) {
		var h = new Map();
		i.readByte();
		for ( i in 0...n )
			h.set(read(), read());
		return h;
	}

	function readArray(n : Int):Dynamic {
		// if ((n & 1) == 0) {
		// 	return getTableEntry(objectTable, n >> 1);
		// }

		// var a = new Array<Value>();
		
		// n >>= 1;

		// objectTable.push(a);

		// var key = readString();
		// var val:Value;

		// while (key != "") {
		// 	val = read();
		// 	a[Std.parseInt(key.toString())] = val;

		// 	key = readString();
		// }
		
		// for( i in 0...n ) {
		// 	a.push(read());
		// }
		
		// return a;

		var ref = n;
	    if ((ref & 1) == 0) {
	        return getTableEntry(objectTable, ref >> 1);
	    }
	    var len = (ref >> 1);
	    var map:Map<String, Value> = null;
	    var i = 0;
	    while (true) {
	        var name = readString();
	        if (name == "" ) {
	            break;
	        }
	        if (map == null) {
	            map = new Map<String, Value>();
	            objectTable.push(map);
	        }
	        map[name.toString()] = read();
	    }
	    if (map == null) {
	        var arr = new Array<Value>();
	        objectTable.push(arr);
	        while (i < len) {
	            arr[i] = read();
	            i++; 
	        }
	        return arr;
	    } else {
	        while(i < len) {
	            map[Std.string(i)] = read();
	            i++; 
	        }
	        return map;
	    }
	}
	
	function readBytes(n : Int) {
		if ((n & 1) == 0) {
			return getTableEntry(objectTable, n >> 1);
		}

		n >>= 1;

		var b = haxe.io.Bytes.alloc(n);
		for ( j in 0...n ) {
			b.set(j, i.readByte());
		}

		objectTable.push(b);
		return b;
	}
	
	function readInt( preShift : Int = 0 ) {
		var integer = 0;
        var seen = 0;

        while (true) {
            var b = cast(i.readByte(), Int);

            if (seen == 3) {
                integer = (integer << 8) | b;
                break;
            }

            integer = (integer << 7) | (b & 0x7f);

            if ((b & 0x80) == 0x80) {
                seen++;
            } else {
                break;
            }
        }

        if (integer > (INT_MAX_VALUE >> 3))
            integer -= (1 << 29);

        return integer;

		// var b = i.readByte() & 255;
		// if (b < 128) {
		// 	return b;
		// }

		// var value = (b & 0x7f) << 7;
		// b = i.readByte() & 255;
		// if (b < 128) {
		// 	return (value | b);
		// }

		// value = (value | (b & 0x7f)) << 7;
		// b = i.readByte() & 255;
		// if (b < 128) {
		// 	return (value | b);
		// }

		// value = (value | (b & 0x7f)) << 8;
		// b = i.readByte() & 255;
		// return (value | b);

		// var ret:UInt = 0;
		// var seen:UInt = 0;
		
		// while(true) {
		// 	var b = i.readByte();

		// 	if (seen == 3) {
		// 		ret = (ret << 8) | b;
		// 	}

		// 	ret = (ret << 7) | (b & 0x7f);

		// 	if ((b & 0x80) == 0x80) {
		// 		seen++;
		// 	} else {
		// 		break;
		// 	}
		// }

		// if (ret > (2147483647 >> 3)) {
		// 	ret -= (1 << 29);
		// }

		// return ret;
	}

	function readString() {
		var ref = readInt();
		var len = 0;
		
		if ((ref & 1) == 0) {
			return getTableEntry(stringTable, ref >> 1);
		}

		len = (ref >> 1);

		if (len == 0) {
			return "";
		}

		var u = new haxe.Utf8(len);

		var c = 0;
		var c2;
		var c3;
		var j = i.position;
		
		while (i.position < (j + len)) {
			c = i.readByte();

			if (c < 0x80) {
				u.addChar(c);
			}
			else if (c > 0x7ff) {
				c2 = i.readByte();
				c3 = i.readByte();
				u.addChar(((c & 0xf) << 12) | ((c2 & 0x3f) << 6) | (c3 & 0x3f));
			} else {
				c2 = i.readByte();
				u.addChar(((c & 31) << 6) | (c2 & 63));
			}
		}
		
		if (u.toString() != "") {
			stringTable.push(u.toString());
		}

		return u.toString();
	}

	function readDate():Date {
		var num = i.readByte();
		
		if ((num & 1) == 0) {
			return cast(getTableEntry(objectTable, num >> 1), Date);
		}
		
		var dt = Date.fromTime(i.readDouble());
		
		objectTable.push(dt);
		
		return dt;
	}

	function getTableEntry(table:Array<Dynamic>, idx:Int):Dynamic {
		if ((table.length - 1) < idx) {
			throw 'Table does not contain required index ${idx}. Max index: ${table.length}';
		}
		
		return table[idx];
	}
	
	public function readWithCode( id ) {
		// var i = this.i;
		return switch( id ) {
		case 0x00: // 0 = Undefined
			AUndefined;
		case 0x01: // 1 = Null
			ANull; 
		case 0x02: // 2 = False
			ABool(false);
		case 0x03: // 3 = True
			ABool(true);
		case 0x04: // 4 = Integer
			var val = readInt();
			val = (val << 3) >> 3;
			AInt( val );
		case 0x05: // 5 = Number
			ANumber( i.readDouble() );
		case 0x06: // 6 = String
			AString( readString() );
		case 0x07: // 7 = LegacyXmlDocument
			throw "XMLDocument unsupported";
		case 0x08: // 8 = Date
			ADate( readDate() );
		case 0x09: // 9 = Array
			AArray( readArray( readInt(1) ) );
		case 0x0a: //10 = Object
			AObject( readObject() );
		case 0x0b: //11 = Xml
			AXml( Xml.parse(readString()) );
		case 0x0c: //12 = ByteArray
			ABytes( readBytes( readInt(1) ) );
		case 0x0d, 0x0e, 0x0f: // 13 = VectorInt, 14 = VectorUInt, 15 = VectorDouble
			AArray( readArray( readInt(1) ) );
		case 0x10: // 16 = VectorObject
			var len = readInt(1);
			readString();
			AArray( readArray( len ) );
		case 0x11: // 17 = Dictionary
			AMap( readMap( readInt(1) ) );
		default:
			throw "Unknown AMF "+id;
		}
	}

	public function read() {
		return readWithCode(i.readByte());
	}
}