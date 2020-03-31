# MCProto
Minecraft Protocol description

Description of Minecraft: Java Edition protocol in Kaitai Struct language

Why?

Protocol description at wiki.vg is pretty good, but it's still in wiki format. In other words, it's __from humans__ and __for humans__.

It may not always be up-to-date, it may have slight errors, it may not be strict enough and it can't be used in real-world applications without being implemented.

At the same time, protocol description in [Kaitai Struct](https://kaitai.io) with Git allows to:

1. Generate protocol parser in any language supported by Kaitai (and there are dozens of them, including Java/C++/C#/Python). You don't
   have to implement it again and again!
2. Check protocol via generated parser and guarantee that it's working
3. Keep track of protocol changes in natural manner

Probably in some future Kaitai will also support not only parser (deserializer), but also serializer generation. 
But being Kaitai user myself I can say that writing serializer already having deserializer is much simpler that writing everything from
scratch.

Hereby I invite everyone interested in MC development to contribute!
