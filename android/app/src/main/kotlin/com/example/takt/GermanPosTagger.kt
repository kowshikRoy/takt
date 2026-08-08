package com.example.takt

import android.content.Context
import opennlp.tools.postag.POSModel
import opennlp.tools.postag.POSTaggerME
import opennlp.tools.tokenize.SimpleTokenizer
import java.io.InputStream
import java.util.Locale
import javax.xml.parsers.DocumentBuilder
import javax.xml.parsers.DocumentBuilderFactory

object GermanPosTagger {

    const val LATEST_UD_MODEL = "opennlp-de-ud-gsd-pos-1.0-1.9.3.bin"

    @Volatile
    private var openNlpTagger: POSTaggerME? = null
    private var isInitializing = false

    fun initModelAsync(context: Context) {
        if (openNlpTagger != null || isInitializing) return
        isInitializing = true

        Thread {
            try {
                val assetManager = context.assets
                val inputStream: InputStream = assetManager.open(LATEST_UD_MODEL)
                initModelFromStream(inputStream)
            } catch (e: Exception) {
                // Graceful fallback to rule-based engine if model loading fails
                e.printStackTrace()
            } finally {
                isInitializing = false
            }
        }.start()
    }

    fun initModelFromStream(inputStream: InputStream) {
        try {
            System.setProperty("javax.xml.parsers.DocumentBuilderFactory", AndroidDocumentBuilderFactory::class.java.name)
        } catch (_: Exception) {}
        val model = POSModel(inputStream)
        openNlpTagger = POSTaggerME(model)
        try {
            inputStream.close()
        } catch (_: Exception) {}
    }

    fun isModelLoaded(): Boolean = openNlpTagger != null

    private val ARTICLES = setOf(
        "der", "die", "das", "den", "dem", "des",
        "ein", "eine", "einen", "einem", "einer", "eines",
        "kein", "keine", "keinen", "keinem", "keiner", "keines",
        "mein", "meine", "meinen", "meinem", "meiner", "meines",
        "dein", "deine", "deinen", "deinem", "deiner", "deines",
        "sein", "seine", "seinen", "seinem", "seiner", "seines",
        "ihr", "ihre", "ihren", "ihrem", "ihrer", "ihres",
        "unser", "unsere", "unseren", "unserem", "unserer", "unseres",
        "euer", "eure", "euren", "eurem", "eurer", "eures",
        "dieser", "diese", "dieses", "diesen", "diesem", "dieses",
        "jener", "jene", "jenes", "jenen", "jenem", "jenes",
        "jeder", "jede", "jedes", "jeden", "jedem",
        "mancher", "manche", "manches", "manchen", "manchem",
        "solcher", "solche", "solches", "solchen", "solchem",
        "welcher", "welche", "welches", "welchen", "welchem",
        "alle", "allen", "aller", "alles", "beide", "beiden"
    )

    private val PREPOSITIONS = setOf(
        "in", "an", "auf", "aus", "bei", "mit", "nach", "von", "zu", "über", "unter",
        "vor", "hinter", "zwischen", "neben", "durch", "für", "gegen", "ohne", "um",
        "bis", "ab", "seit", "ausser", "außer", "trotz", "während", "wegen", "statt",
        "am", "im", "ans", "ins", "beim", "vom", "zum", "zur", "überm", "unterm", "vorm", "hinters"
    )

    private val CONJUNCTIONS = setOf(
        "und", "oder", "aber", "denn", "sondern", "doch", "jedoch",
        "dass", "daß", "weil", "wenn", "als", "ob", "obwohl", "obgleich", "da",
        "während", "damit", "sodass", "so dass", "indem", "bevor", "nachdem", "ehe",
        "seit", "seitdem", "bis", "solange", "sowie", "sowohl", "weder", "entweder"
    )

    private val PRONOUNS = setOf(
        "ich", "du", "er", "sie", "es", "wir", "ihr", "sie", "sie",
        "mich", "dich", "ihn", "sie", "es", "uns", "euch", "sie",
        "mir", "dir", "ihm", "ihr", "ihm", "uns", "euch", "ihnen",
        "sich", "einander", "man", "jemand", "niemand", "etwas", "nichts",
        "wer", "was", "wen", "wem", "wessen", "selbst", "selber"
    )

    private val COMMON_ADVERBS = setOf(
        "heute", "gestern", "morgen", "oft", "immer", "nie", "selten", "manchmal",
        "fast", "sehr", "ganz", "hier", "dort", "da", "damals", "jetzt", "nun",
        "bald", "bereits", "schon", "noch", "gerne", "gern", "leider", "vielleicht",
        "wirklich", "eigentlich", "überhaupt", "besonders", "auch", "nur", "gar",
        "warum", "wo", "woher", "wohin", "wann", "wie", "deshalb", "darum", "deswegen",
        "trotzdem", "außerdem", "sonst", "wieder", "weiter", "zurück", "zusammen"
    )

    private val SEPARABLE_PREFIXES = setOf(
        "ab", "an", "auf", "aus", "bei", "ein", "fest", "fort", "her", "hin",
        "los", "mit", "nach", "vor", "weg", "weiter", "zu", "zurück", "zusammen"
    )

    private val AUX_MODAL_VERBS = setOf(
        "bin", "bist", "ist", "sind", "seid", "war", "warst", "waren", "wart", "gewesen", "sei", "seien", "wäre", "wären", "sein",
        "habe", "hast", "hat", "haben", "habt", "hatte", "hattest", "hatten", "hattet", "gehabt", "hätte", "hätten",
        "werde", "wirst", "wird", "werden", "werdet", "wurde", "wurdest", "wurden", "wurdet", "geworden", "worden", "würde", "würden",
        "kann", "kannst", "können", "könnt", "konnte", "konnten", "gekonnt", "könnte", "könnten",
        "muss", "muß", "musst", "müssen", "müsst", "musste", "mussten", "gemusst", "müsste", "müssten",
        "will", "willst", "wollen", "wollt", "wollte", "wollten", "gewollt",
        "soll", "sollst", "sollen", "sollt", "sollte", "sollten", "gesollt",
        "darf", "darfst", "dürfen", "dürft", "durfte", "durften", "gedurft", "dürfte", "dürften",
        "mag", "magst", "mögen", "mögt", "mochte", "mochten", "gemocht", "möchte", "möchtest", "möchten", "möchtet"
    )

    private val NUMBER_WORDS = setOf(
        "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn",
        "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn",
        "zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig",
        "hundert", "tausend", "million", "millionen", "milliarde", "milliarden"
    )

    fun tagText(text: String): List<Map<String, String>> {
        if (text.isBlank()) return emptyList()

        // 1. Try Apache OpenNLP Statistical Universal Dependencies (UD) Model first
        val tagger = openNlpTagger
        if (tagger != null) {
            try {
                val tokens = SimpleTokenizer.INSTANCE.tokenize(text)
                val rawTags = tagger.tag(tokens)
                val results = mutableListOf<Map<String, String>>()

                for (i in tokens.indices) {
                    val rawToken = tokens[i]
                    val cleanToken = rawToken.replace(Regex("[^\\wäöüÄÖÜß]"), "")
                    if (cleanToken.isEmpty()) continue

                    val rawTag = rawTags[i]
                    val mappedPos = mapTagToCanonical(rawTag, cleanToken)
                    val prevToken = if (i > 0) tokens[i - 1].replace(Regex("[^\\wäöüÄÖÜß]"), "").lowercase(Locale.GERMAN) else ""

                    val map = mutableMapOf(
                        "token" to cleanToken,
                        "pos" to mappedPos,
                        "lemma" to cleanToken,
                        "tag" to rawTag,
                        "engine" to "opennlp",
                        "model" to "opennlp-de-ud-gsd-pos"
                    )
                    if (mappedPos == "noun") {
                        val gender = inferNounGender(cleanToken, prevToken)
                        if (gender.isNotEmpty()) {
                            map["gender"] = gender
                        }
                    }
                    results.add(map)
                }

                if (results.isNotEmpty()) {
                    return results
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 2. High-speed morpho-syntactic rule-based fallback
        return tagTextRuleBased(text)
    }

    private fun mapTagToCanonical(tag: String, token: String): String {
        val upper = tag.uppercase(Locale.ROOT)
        return when {
            // Universal Dependencies (UD / UPOS) tags
            upper == "NOUN" || upper == "PROPN" -> "noun"
            upper == "VERB" || upper == "AUX" -> "verb"
            upper == "ADJ" -> "adj"
            upper == "ADV" -> "adv"
            upper == "DET" -> "art"
            upper == "ADP" -> "prep"
            upper == "PRON" -> "pron"
            upper == "CCONJ" || upper == "SCONJ" -> "conj"
            upper == "NUM" -> "num"
            upper == "PART" -> "part"
            upper == "INTJ" -> "interj"
            // Legacy STTS tags compatibility
            upper.startsWith("NN") || upper.startsWith("NE") -> "noun"
            upper.startsWith("VV") || upper.startsWith("VA") || upper.startsWith("VM") -> "verb"
            upper.startsWith("ADJ") -> "adj"
            upper.startsWith("ADV") || upper == "PAV" || upper == "PROAV" -> "adv"
            upper == "ART" -> "art"
            upper.startsWith("APP") || upper.startsWith("APZ") -> "prep"
            upper.startsWith("PP") || upper.startsWith("PR") || upper.startsWith("PI") || upper.startsWith("PW") -> "pron"
            upper.startsWith("KO") -> "conj"
            upper == "CARD" -> "num"
            upper == "PTKVZ" || upper.startsWith("PTK") -> "part"
            upper == "ITJ" -> "interj"
            token.isNotEmpty() && token[0].isUpperCase() -> "noun"
            else -> "unknown"
        }
    }

    private fun tagTextRuleBased(text: String): List<Map<String, String>> {
        val tokens = text
            .split(Regex("[\\s]+"))
            .map { it.replace(Regex("^[^\\wäöüÄÖÜß]+|[^\\wäöüÄÖÜß.]+$"), "") }
            .filter { it.isNotEmpty() }

        val results = mutableListOf<Map<String, String>>()

        for (i in tokens.indices) {
            val rawToken = tokens[i]
            val cleanToken = rawToken.replace(Regex("[^\\wäöüÄÖÜß]"), "")
            val lower = cleanToken.lowercase(Locale.GERMAN)

            if (cleanToken.isEmpty()) continue

            var pos = "unknown"
            var gender = ""

            val prevToken = if (i > 0) tokens[i - 1].replace(Regex("[^\\wäöüÄÖÜß]"), "").lowercase(Locale.GERMAN) else ""
            val nextToken = if (i < tokens.size - 1) tokens[i + 1].replace(Regex("[^\\wäöüÄÖÜß]"), "").lowercase(Locale.GERMAN) else ""

            val isFirstWordInSentence = i == 0 || tokens[i - 1].endsWith(".") || tokens[i - 1].endsWith("!") || tokens[i - 1].endsWith("?")
            val isCapitalized = cleanToken.isNotEmpty() && cleanToken[0].isUpperCase()

            when {
                ARTICLES.contains(lower) -> pos = "art"
                PREPOSITIONS.contains(lower) -> pos = "prep"
                CONJUNCTIONS.contains(lower) -> pos = "conj"
                PRONOUNS.contains(lower) -> pos = "pron"
                AUX_MODAL_VERBS.contains(lower) -> pos = "verb"
                NUMBER_WORDS.contains(lower) || cleanToken.matches(Regex("^\\d+\\.?$")) -> pos = "num"
                COMMON_ADVERBS.contains(lower) && (!isCapitalized || isFirstWordInSentence) -> pos = "adv"
                SEPARABLE_PREFIXES.contains(lower) && (i == tokens.size - 1 || rawToken.endsWith(".") || rawToken.endsWith(",") || nextToken.isEmpty()) -> pos = "part"
            }

            if (pos == "unknown") {
                val isPrecededByArticleOrPrep = ARTICLES.contains(prevToken) || PREPOSITIONS.contains(prevToken)

                if (isPrecededByArticleOrPrep && isCapitalized) {
                    pos = "noun"
                } else if (isCapitalized && !isFirstWordInSentence) {
                    pos = "noun"
                } else if (hasNounSuffix(cleanToken)) {
                    pos = "noun"
                } else if (hasAdjectiveSuffix(cleanToken) || (isPrecededByArticleOrPrep && !isCapitalized && nextToken.isNotEmpty() && isCapitalized(nextToken))) {
                    pos = "adj"
                } else if (hasAdverbSuffix(cleanToken)) {
                    pos = "adv"
                } else if (hasVerbSuffix(cleanToken)) {
                    pos = "verb"
                } else if (isCapitalized) {
                    pos = "noun"
                }
            }

            if (pos == "noun") {
                gender = inferNounGender(cleanToken, prevToken)
            }

            val map = mutableMapOf(
                "token" to cleanToken,
                "pos" to pos,
                "lemma" to cleanToken,
                "engine" to "rule_based"
            )
            if (gender.isNotEmpty()) {
                map["gender"] = gender
            }
            results.add(map)
        }

        return results
    }

    private fun isCapitalized(word: String): Boolean {
        return word.isNotEmpty() && word[0].isUpperCase()
    }

    private fun hasNounSuffix(word: String): Boolean {
        val lower = word.lowercase(Locale.GERMAN)
        return lower.endsWith("ung") || lower.endsWith("heit") || lower.endsWith("keit") ||
                lower.endsWith("schaft") || lower.endsWith("tät") || lower.endsWith("ismus") ||
                lower.endsWith("ion") || lower.endsWith("ik") || lower.endsWith("ment") ||
                lower.endsWith("ling") || lower.endsWith("nis") || lower.endsWith("tum") ||
                lower.endsWith("chen") || lower.endsWith("lein")
    }

    private fun hasAdjectiveSuffix(word: String): Boolean {
        val lower = word.lowercase(Locale.GERMAN)
        return lower.endsWith("isch") || lower.endsWith("lich") || lower.endsWith("ig") ||
                lower.endsWith("bar") || lower.endsWith("haft") || lower.endsWith("los") ||
                lower.endsWith("sam") || lower.endsWith("voll") || lower.endsWith("abel") ||
                lower.endsWith("ibel") || lower.endsWith("ell") || lower.endsWith("iv") ||
                lower.endsWith("sten") || lower.endsWith("ster") || lower.endsWith("ste")
    }

    private fun hasAdverbSuffix(word: String): Boolean {
        val lower = word.lowercase(Locale.GERMAN)
        return lower.endsWith("weise") || lower.endsWith("wärts") || lower.endsWith("halber")
    }

    private fun hasVerbSuffix(word: String): Boolean {
        val lower = word.lowercase(Locale.GERMAN)
        return lower.endsWith("ieren") || lower.endsWith("iert") ||
                (lower.endsWith("en") && !hasNounSuffix(word)) || lower.endsWith("test") ||
                lower.endsWith("est")
    }

    private fun inferNounGender(word: String, prevArticle: String): String {
        when (prevArticle) {
            "der" -> return "m"
            "die" -> return "f"
            "das" -> return "n"
            "den", "dem", "des" -> return "m"
            "einem", "eines" -> return "n"
            "einer" -> return "f"
        }

        val lower = word.lowercase(Locale.GERMAN)
        return when {
            lower.endsWith("ung") || lower.endsWith("heit") || lower.endsWith("keit") ||
                    lower.endsWith("schaft") || lower.endsWith("tät") || lower.endsWith("ion") ||
                    lower.endsWith("ik") -> "f"
            lower.endsWith("ismus") || lower.endsWith("ling") || lower.endsWith("or") ||
                    lower.endsWith("ist") -> "m"
            lower.endsWith("chen") || lower.endsWith("lein") || lower.endsWith("ment") ||
                    lower.endsWith("tum") || lower.endsWith("um") -> "n"
            else -> ""
        }
    }
}

class AndroidDocumentBuilderFactory : DocumentBuilderFactory() {
    private val delegate: DocumentBuilderFactory by lazy {
        try {
            val factoryClass = Class.forName("org.apache.harmony.xml.parsers.DocumentBuilderFactoryImpl")
            factoryClass.getDeclaredConstructor().newInstance() as DocumentBuilderFactory
        } catch (_: Exception) {
            this
        }
    }

    override fun newDocumentBuilder(): DocumentBuilder {
        val factoryClass = Class.forName("org.apache.harmony.xml.parsers.DocumentBuilderFactoryImpl")
        val factory = factoryClass.getDeclaredConstructor().newInstance() as DocumentBuilderFactory
        return factory.newDocumentBuilder()
    }

    override fun setAttribute(name: String?, value: Any?) {
        try {
            val factoryClass = Class.forName("org.apache.harmony.xml.parsers.DocumentBuilderFactoryImpl")
            val factory = factoryClass.getDeclaredConstructor().newInstance() as DocumentBuilderFactory
            factory.setAttribute(name, value)
        } catch (_: Exception) {}
    }

    override fun getAttribute(name: String?): Any? = null

    override fun setFeature(name: String?, value: Boolean) {
        // Suppress UnsupportedOperationException for XMLConstants.FEATURE_SECURE_PROCESSING on Android
    }

    override fun getFeature(name: String?): Boolean = false
}
