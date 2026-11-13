package fr.podavio.podavio

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.wear.compose.foundation.SwipeToDismissValue
import androidx.wear.compose.foundation.rememberSwipeToDismissBoxState
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.SwipeToDismissBox
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.items
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.ScalingLazyColumn
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.rememberScalingLazyListState
import fr.podavio.podavio.wear.WearCommands
import fr.podavio.podavio.wear.WearFolders
import fr.podavio.podavio.wear.WearItem
import fr.podavio.podavio.wear.WearState
import kotlinx.coroutines.launch

@Composable
fun WearApp() {
    val playback by WatchLink.state.collectAsState()
    val reachable by WatchLink.reachable.collectAsState()
    var stack by remember { mutableStateOf(listOf<String>()) }
    MaterialTheme(colors = podavioColors()) {
        if (stack.isEmpty()) {
            NowPlaying(
                state = playback,
                reachable = reachable,
                onLists = { stack = listOf(WearFolders.ROOT) },
            )
        } else {
            key(stack) {
                FolderScreen(
                    parentId = stack.last(),
                    onOpen = { id -> stack = stack + id },
                    onPlayed = { stack = emptyList() },
                    onBack = { stack = stack.dropLast(1) },
                )
            }
        }
    }
}

@Composable
private fun NowPlaying(state: WearState, reachable: Boolean, onLists: () -> Unit) {
    val scope = rememberCoroutineScope()
    val listState = rememberScalingLazyListState()
    Scaffold(
        timeText = { TimeText() },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) },
    ) {
        ScalingLazyColumn(modifier = Modifier.fillMaxSize(), state = listState) {
            item {
                Text(
                    text = if (state.hasEpisode) state.title.ifBlank { "Lecture" } else "Rien en cours",
                    style = MaterialTheme.typography.title3,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            item {
                Text(
                    text =
                        when {
                            !reachable -> "Téléphone injoignable"
                            state.artist.isNotBlank() -> state.artist
                            else -> " "
                        },
                    style = MaterialTheme.typography.body2,
                    color = MaterialTheme.colors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            item {
                WideButton(if (state.playing) "Pause" else "Lecture") {
                    scope.launch {
                        val name = if (state.playing) WearCommands.PAUSE else WearCommands.PLAY
                        WatchLink.command(name)
                    }
                }
            }
            item {
                WideButton("Reculer") {
                    scope.launch { WatchLink.command(WearCommands.SKIP_BACK) }
                }
            }
            item {
                WideButton("Avancer") {
                    scope.launch { WatchLink.command(WearCommands.SKIP_FORWARD) }
                }
            }
            item { WideButton("Listes", onLists) }
        }
    }
}

@Composable
private fun FolderScreen(
    parentId: String,
    onOpen: (String) -> Unit,
    onPlayed: () -> Unit,
    onBack: () -> Unit,
) {
    val dismissState = rememberSwipeToDismissBoxState()
    LaunchedEffect(dismissState.currentValue) {
        if (dismissState.currentValue == SwipeToDismissValue.Dismissed) onBack()
    }
    SwipeToDismissBox(state = dismissState) { isBackground ->
        if (!isBackground) {
            FolderList(parentId = parentId, onOpen = onOpen, onPlayed = onPlayed)
        }
    }
}

@Composable
private fun FolderList(parentId: String, onOpen: (String) -> Unit, onPlayed: () -> Unit) {
    val scope = rememberCoroutineScope()
    var rows by remember(parentId) { mutableStateOf<List<WearItem>>(emptyList()) }
    var status by remember(parentId) { mutableStateOf("Chargement") }
    val listState = rememberScalingLazyListState()
    LaunchedEffect(parentId) {
        val reply = WatchLink.command(WearCommands.GET_CHILDREN, parentId)
        if (reply == null) {
            rows = emptyList()
            status = "Téléphone injoignable"
        } else {
            rows = reply.items
            status = if (reply.items.isEmpty()) "Aucun épisode" else ""
        }
    }
    Scaffold(
        timeText = { TimeText() },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) },
    ) {
        ScalingLazyColumn(modifier = Modifier.fillMaxSize(), state = listState) {
            if (status.isNotEmpty()) {
                item {
                    Text(
                        text = status,
                        style = MaterialTheme.typography.body2,
                        textAlign = TextAlign.Center,
                    )
                }
            }
            items(rows.size) { index ->
                val row = rows[index]
                Chip(
                    label = {
                        Text(
                            text = row.title,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                    secondaryLabel =
                        if (row.subtitle.isBlank()) {
                            null
                        } else {
                            {
                                Text(
                                    text = row.subtitle,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                        },
                    onClick = {
                        when {
                            row.playable ->
                                scope.launch {
                                    WatchLink.command(WearCommands.PLAY_FROM_MEDIA_ID, row.id)
                                    onPlayed()
                                }
                            row.id != WearFolders.HINT_OPEN -> onOpen(row.id)
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun WideButton(label: String, onClick: () -> Unit) {
    Button(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Text(label)
    }
}

private fun podavioColors() =
    Colors(
        primary = Color(0xFFED2939),
        primaryVariant = Color(0xFFB71C1C),
        secondary = Color(0xFF2E895D),
        secondaryVariant = Color(0xFF1B5E20),
        background = Color.Black,
        surface = Color(0xFF141414),
        error = Color(0xFFED2939),
        onPrimary = Color.White,
        onSecondary = Color.White,
        onBackground = Color.White,
        onSurface = Color.White,
        onSurfaceVariant = Color(0xFFBDBDBD),
        onError = Color.White,
    )
