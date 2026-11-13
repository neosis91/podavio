package fr.podavio.podavio

/**
 * Relais de `updatePlaybackState` vers la montre.
 * Reste nul dans le build F-Droid : le pont n’est compilé qu’avec `-PpodavioWear=true`.
 */
object WearPlaybackFanout {
    @Volatile
    var dispatch: ((Map<*, *>) -> Unit)? = null
}
