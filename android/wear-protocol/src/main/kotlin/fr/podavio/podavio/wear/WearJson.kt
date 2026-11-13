package fr.podavio.podavio.wear

internal object WearJson {
    fun parse(bytes: ByteArray): Any? = Reader(bytes.toString(Charsets.UTF_8)).read()

    private class Reader(private val text: String) {
        private var index = 0

        fun read(): Any? {
            val value = value()
            skip()
            if (index != text.length) fail("trailing")
            return value
        }

        private fun value(): Any? {
            skip()
            if (index >= text.length) fail("eof")
            return when (val char = text[index]) {
                '{' -> obj()
                '[' -> arr()
                '"' -> str()
                't' -> literal("true", true)
                'f' -> literal("false", false)
                'n' -> literal("null", null)
                else -> if (char == '-' || char.isDigit()) number() else fail("value")
            }
        }

        private fun obj(): Map<String, Any?> {
            expect('{')
            val map = LinkedHashMap<String, Any?>()
            if (consume('}')) return map
            while (true) {
                val key = str()
                expect(':')
                map[key] = value()
                when {
                    consume('}') -> return map
                    consume(',') -> continue
                    else -> fail("object")
                }
            }
        }

        private fun arr(): List<Any?> {
            expect('[')
            val list = ArrayList<Any?>()
            if (consume(']')) return list
            while (true) {
                list.add(value())
                when {
                    consume(']') -> return list
                    consume(',') -> continue
                    else -> fail("array")
                }
            }
        }

        private fun str(): String {
            expect('"')
            val out = StringBuilder()
            while (index < text.length) {
                when (val char = text[index++]) {
                    '"' -> return out.toString()
                    '\\' -> {
                        if (index >= text.length) fail("escape")
                        out.append(
                            when (val escaped = text[index++]) {
                                '"', '\\', '/' -> escaped
                                'b' -> '\b'
                                'f' -> '\u000C'
                                'n' -> '\n'
                                'r' -> '\r'
                                't' -> '\t'
                                'u' -> unicode()
                                else -> fail("escape")
                            },
                        )
                    }
                    else -> out.append(char)
                }
            }
            fail("string")
        }

        private fun unicode(): Char {
            if (index + 4 > text.length) fail("unicode")
            val hex = text.substring(index, index + 4)
            index += 4
            return hex.toInt(16).toChar()
        }

        private fun literal(token: String, value: Any?): Any? {
            if (!text.startsWith(token, index)) fail(token)
            index += token.length
            return value
        }

        private fun number(): Long {
            val start = index
            if (text[index] == '-') index++
            if (index >= text.length || !text[index].isDigit()) fail("number")
            while (index < text.length && text[index].isDigit()) index++
            if (index < text.length && text[index] in ".eE") fail("integer")
            return text.substring(start, index).toLong()
        }

        private fun skip() {
            while (index < text.length && text[index].isWhitespace()) index++
        }

        private fun expect(char: Char) {
            skip()
            if (index >= text.length || text[index] != char) fail("expected $char")
            index++
        }

        private fun consume(char: Char): Boolean {
            skip()
            if (index < text.length && text[index] == char) {
                index++
                return true
            }
            return false
        }

        private fun fail(reason: String): Nothing {
            throw IllegalArgumentException("json $reason at $index")
        }
    }
}

internal fun jsonQuote(value: String): String {
    val out = StringBuilder(value.length + 2)
    out.append('"')
    for (char in value) {
        when (char) {
            '"' -> out.append("\\\"")
            '\\' -> out.append("\\\\")
            '\b' -> out.append("\\b")
            '\u000C' -> out.append("\\f")
            '\n' -> out.append("\\n")
            '\r' -> out.append("\\r")
            '\t' -> out.append("\\t")
            else ->
                if (char < ' ') {
                    out.append("\\u")
                    out.append(char.code.toString(16).padStart(4, '0'))
                } else {
                    out.append(char)
                }
        }
    }
    out.append('"')
    return out.toString()
}
