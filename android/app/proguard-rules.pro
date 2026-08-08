# ProGuard / R8 Rules for Takt

# Apache OpenNLP & SLF4J
-dontwarn org.slf4j.**
-dontwarn opennlp.**
-keep class opennlp.** { *; }
-keep interface opennlp.** { *; }
