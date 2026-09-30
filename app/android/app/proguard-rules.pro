# The text-recognition plugin can also load Chinese, Devanagari, Japanese and
# Korean models, which this app doesn't bundle. R8 must not treat their
# absence as an error.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
