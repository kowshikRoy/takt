package com.example.takt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.io.FileInputStream

class GermanPosTaggerTest {

    @Before
    fun setUp() {
        // Load the downloaded OpenNLP Universal Dependencies model file directly from assets
        val modelFile = File("src/main/assets/opennlp-de-ud-gsd-pos-1.0-1.9.3.bin")
        if (modelFile.exists()) {
            GermanPosTagger.initModelFromStream(FileInputStream(modelFile))
        }
    }

    @Test
    fun testOpenNlpModelLoaded() {
        assertTrue("OpenNLP model should be loaded", GermanPosTagger.isModelLoaded())
    }

    @Test
    fun testTitelSentencePosTagging() {
        val sentence = "“Myoho-Renge-Kyo” ist der Titel der chinesischen Übersetzung des Lotos-Sutras."
        val results = GermanPosTagger.tagText(sentence)

        assertTrue("Results should not be empty", results.isNotEmpty())

        val tokenMap = results.associateBy { it["token"] }

        // 1. Verify "ist" is tagged as a Verb
        val istToken = tokenMap["ist"]
        assertNotNull("Token 'ist' should be found", istToken)
        assertEquals("verb", istToken?.get("pos"))

        // 2. Verify "der" is tagged as an Article / Determiner
        val derToken = tokenMap["der"]
        assertNotNull("Token 'der' should be found", derToken)
        assertEquals("art", derToken?.get("pos"))

        // 3. Verify "Titel" is correctly tagged as Noun and NOT Verb!
        val titelToken = tokenMap["Titel"]
        assertNotNull("Token 'Titel' should be found", titelToken)
        assertEquals("noun", titelToken?.get("pos"))
        assertEquals("opennlp", titelToken?.get("engine"))
        assertEquals("m", titelToken?.get("gender"))

        // 4. Verify "chinesischen" is tagged as Adjective
        val adjToken = tokenMap["chinesischen"]
        assertNotNull("Token 'chinesischen' should be found", adjToken)
        assertEquals("adj", adjToken?.get("pos"))

        // 5. Verify "Übersetzung" is tagged as Noun
        val uebersetzungToken = tokenMap["Übersetzung"]
        assertNotNull("Token 'Übersetzung' should be found", uebersetzungToken)
        assertEquals("noun", uebersetzungToken?.get("pos"))
    }

    @Test
    fun testBuddhismusSentence() {
        val sentence = "Buddhismus ist eine jahrtausendealte Religion."
        val results = GermanPosTagger.tagText(sentence)
        val tokenMap = results.associateBy { it["token"] }

        val buddhismusToken = tokenMap["Buddhismus"]
        assertNotNull("Buddhismus should be tagged", buddhismusToken)
        assertEquals("noun", buddhismusToken?.get("pos"))
        assertEquals("m", buddhismusToken?.get("gender"))
    }

    @Test
    fun testEntitySentence() {
        val sentence = "Nichiren Daishonin lebte im 13. Jahrhundert in Japan."
        val results = GermanPosTagger.tagText(sentence)
        val tokenMap = results.associateBy { it["token"] }

        val lebteToken = tokenMap["lebte"]
        assertNotNull("lebte should be tagged", lebteToken)
        assertEquals("verb", lebteToken?.get("pos"))

        val inToken = tokenMap["in"]
        assertNotNull("in should be tagged", inToken)
        assertEquals("prep", inToken?.get("pos"))

        val japanToken = tokenMap["Japan"]
        assertNotNull("Japan should be tagged", japanToken)
        assertEquals("noun", japanToken?.get("pos"))
    }
}
