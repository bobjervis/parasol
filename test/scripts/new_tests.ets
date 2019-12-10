comile() { ";" }

compile() { "string a; string b; string16 c; a = b + c;" }
compile() { "string a; string b; substring c; a = b + c;" }
compile() { "string a; string b; substring16 c; a = b + c;" }
compile() { "string a; string16 b; string c; a = b + c;" }
compile() { "string a; string16 b; string16 c; a = b + c;" }
compile() { "string a; string16 b; substring c; a = b + c;" }
compile() { "string a; string16 b; substring16 c; a = b + c;" }
compile() { "string a; substring b; string c; a = b + c;" }
compile() { "string a; substring b; string16 c; a = b + c;" }
compile() { "string a; substring b; substring c; a = b + c;" }
compile() { "string a; substring b; substring16 c; a = b + c;" }
compile() { "string a; substring16 b; string c; a = b + c;" }
compile() { "string a; substring16 b; string16 c; a = b + c;" }
compile() { "string a; substring16 b; substring c; a = b + c;" }
compile() { "string a; substring16 b; substring16 c; a = b + c;" }
compile() { "string16 a; string b; string c; a = b + c;" }
compile() { "string16 a; string b; string16 c; a = b + c;" }
compile() { "string16 a; string b; substring c; a = b + c;" }
compile() { "string16 a; string b; substring16 c; a = b + c;" }
compile() { "string16 a; string16 b; string c; a = b + c;" }
compile() { "string16 a; string16 b; string16 c; a = b + c;" }
compile() { "string16 a; string16 b; substring c; a = b + c;" }
compile() { "string16 a; string16 b; substring16 c; a = b + c;" }
compile() { "string16 a; substring b; string c; a = b + c;" }
compile() { "string16 a; substring b; string16 c; a = b + c;" }
compile() { "string16 a; substring b; substring c; a = b + c;" }
compile() { "string16 a; substring b; substring16 c; a = b + c;" }
compile() { "string16 a; substring16 b; string c; a = b + c;" }
compile() { "string16 a; substring16 b; string16 c; a = b + c;" }
compile() { "string16 a; substring16 b; substring c; a = b + c;" }
compile() { "string16 a; substring16 b; substring16 c; a = b + c;" }

compile() { "substring x; boolean b = x != null;" }
compile() { "substring16 x; boolean b = x != null;" }
