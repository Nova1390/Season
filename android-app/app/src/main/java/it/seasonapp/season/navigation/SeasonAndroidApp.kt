package it.seasonapp.season.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.IconButton
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import it.seasonapp.season.core.design.SeasonTheme
import it.seasonapp.season.core.env.SeasonEnvironment
import it.seasonapp.season.features.auth.AuthGateScreen
import it.seasonapp.season.features.auth.AuthUiState
import it.seasonapp.season.features.auth.AuthViewModel
import it.seasonapp.season.features.auth.SeasonProfile
import it.seasonapp.season.features.create.CreateScreen
import it.seasonapp.season.features.fridge.FridgeScreen
import it.seasonapp.season.features.fridge.FridgeViewModel
import it.seasonapp.season.features.home.HomeScreen
import it.seasonapp.season.features.profile.ProfileScreen
import it.seasonapp.season.features.recipes.RecipeDetailScreen
import it.seasonapp.season.features.recipes.SeasonRecipe
import it.seasonapp.season.features.recipestate.UserRecipeStateViewModel
import it.seasonapp.season.features.search.SearchScreen
import it.seasonapp.season.features.today.TodayScreen

@Composable
fun SeasonAndroidApp() {
    SeasonTheme {
        val context = LocalContext.current
        val authViewModel: AuthViewModel = viewModel()
        val authState by authViewModel.uiState.collectAsStateWithLifecycle()

        when (val state = authState) {
            is AuthUiState.SignedIn -> SeasonShell(
                profile = state.profile,
                onLogout = { authViewModel.signOut(context) },
            )
            else -> AuthGateScreen(
                state = state,
                onGoogleSignIn = { authViewModel.signInWithGoogle(context) },
                onEmailSignIn = authViewModel::signInWithEmail,
                onEmailSignUp = authViewModel::signUpWithEmail,
                onSaveUsername = authViewModel::saveUsername,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SeasonShell(profile: SeasonProfile, onLogout: () -> Unit) {
    var selectedDestination by rememberSaveable { mutableStateOf(SeasonDestination.Home) }
    var showFridge by rememberSaveable { mutableStateOf(false) }
    var selectedRecipe by remember { mutableStateOf<SeasonRecipe?>(null) }
    val activeRecipe = selectedRecipe
    val lifecycleOwner = LocalLifecycleOwner.current
    val recipeStateViewModel: UserRecipeStateViewModel = viewModel()
    val fridgeViewModel: FridgeViewModel = viewModel()

    LaunchedEffect(profile.id) {
        recipeStateViewModel.initialize(profile.id)
        fridgeViewModel.initialize(profile.id)
    }

    DisposableEffect(lifecycleOwner, recipeStateViewModel, fridgeViewModel) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START) {
                recipeStateViewModel.flushPendingRecipeStateMutations()
                fridgeViewModel.refresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    BackHandler(enabled = activeRecipe != null || showFridge) {
        if (activeRecipe != null) {
            selectedRecipe = null
        } else {
            showFridge = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    if (activeRecipe != null || showFridge) {
                        IconButton(onClick = {
                            if (activeRecipe != null) {
                                selectedRecipe = null
                            } else {
                                showFridge = false
                            }
                        }) {
                            Text(
                                text = "‹",
                                style = androidx.compose.material3.MaterialTheme.typography.headlineMedium,
                            )
                        }
                    }
                },
                title = {
                    Text(
                        text = when {
                            activeRecipe != null -> "Ricetta"
                            showFridge -> "Frigo"
                            else -> selectedDestination.title
                        },
                        style = androidx.compose.material3.MaterialTheme.typography.titleLarge,
                    )
                },
                actions = {
                    if (activeRecipe == null && !showFridge) {
                        TextButton(
                            onClick = {
                                selectedRecipe = null
                                showFridge = true
                            },
                        ) {
                            Text("Frigo")
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = androidx.compose.material3.MaterialTheme.colorScheme.background,
                ),
            )
        },
        bottomBar = {
            NavigationBar {
                SeasonDestination.entries.forEach { destination ->
                    NavigationBarItem(
                        selected = selectedDestination == destination,
                        onClick = {
                            selectedRecipe = null
                            showFridge = false
                            selectedDestination = destination
                        },
                        icon = { Text(destination.label.first().toString(), fontWeight = FontWeight.Bold) },
                        label = { Text(destination.label) },
                    )
                }
            }
        },
    ) { padding ->
        Surface(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            color = androidx.compose.material3.MaterialTheme.colorScheme.background,
        ) {
            if (activeRecipe != null) {
                RecipeDetailScreen(recipe = activeRecipe, recipeStateViewModel = recipeStateViewModel)
            } else if (showFridge) {
                FridgeScreen(fridgeViewModel = fridgeViewModel)
            } else {
                when (selectedDestination) {
                    SeasonDestination.Home -> HomeScreen(onRecipeSelected = { selectedRecipe = it })
                    SeasonDestination.Search -> SearchScreen(onRecipeSelected = { selectedRecipe = it })
                    SeasonDestination.Create -> CreateScreen()
                    SeasonDestination.Today -> TodayScreen()
                    SeasonDestination.Profile -> ProfileScreen(
                        profile = profile,
                        onLogout = {
                            recipeStateViewModel.clearLocalRecipeStateOnLogout()
                            fridgeViewModel.clearLocalStateOnLogout()
                            onLogout()
                        },
                    )
                }
            }
        }
    }
}

@Composable
internal fun SeasonScreenFrame(
    title: String,
    subtitle: String,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Text(
            text = title,
            style = androidx.compose.material3.MaterialTheme.typography.headlineMedium,
        )
        Text(
            text = subtitle,
            style = androidx.compose.material3.MaterialTheme.typography.bodyLarge,
            color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
        )
        content()
    }
}

@Composable
internal fun SeasonStatusCard(
    title: String,
    body: String,
    action: String? = null,
    onAction: (() -> Unit)? = null,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = androidx.compose.material3.MaterialTheme.colorScheme.surface,
        ),
        border = androidx.compose.foundation.BorderStroke(
            width = 1.dp,
            color = androidx.compose.material3.MaterialTheme.colorScheme.outline,
        ),
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = title,
                style = androidx.compose.material3.MaterialTheme.typography.titleMedium,
            )
            Text(
                text = body,
                style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
                color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (action != null && onAction != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Button(
                        onClick = onAction,
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    ) {
                        Text(action)
                    }
                }
            }
        }
    }
}

@Composable
internal fun EnvironmentCard() {
    val environment = SeasonEnvironment.current
    SeasonStatusCard(
        title = "Ambiente ${environment.kind}",
        body = if (environment.isConfigured) {
            "Supabase configurato per questo build type."
        } else {
            "Configura la anon key con Gradle property o variabile ambiente prima dei test backend."
        },
    )
}
