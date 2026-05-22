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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.IconButton
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
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
import it.seasonapp.season.core.design.SeasonCanvas
import it.seasonapp.season.core.design.SeasonKicker
import it.seasonapp.season.core.design.SeasonPanel
import it.seasonapp.season.core.design.SeasonPill
import it.seasonapp.season.core.design.SeasonPillEmphasis
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
import it.seasonapp.season.features.shopping.ShoppingScreen
import it.seasonapp.season.features.shopping.ShoppingViewModel
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
    var showShopping by rememberSaveable { mutableStateOf(false) }
    var selectedRecipe by remember { mutableStateOf<SeasonRecipe?>(null) }
    val activeRecipe = selectedRecipe
    val lifecycleOwner = LocalLifecycleOwner.current
    val recipeStateViewModel: UserRecipeStateViewModel = viewModel()
    val fridgeViewModel: FridgeViewModel = viewModel()
    val shoppingViewModel: ShoppingViewModel = viewModel()

    LaunchedEffect(profile.id) {
        recipeStateViewModel.initialize(profile.id)
        fridgeViewModel.initialize(profile.id)
        shoppingViewModel.initialize(profile.id)
    }

    DisposableEffect(lifecycleOwner, recipeStateViewModel, fridgeViewModel, shoppingViewModel) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START) {
                recipeStateViewModel.flushPendingRecipeStateMutations()
                fridgeViewModel.flushPendingFridgeMutations()
                shoppingViewModel.flushPendingShoppingMutations()
                fridgeViewModel.refresh()
                shoppingViewModel.refresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    BackHandler(enabled = activeRecipe != null || showFridge || showShopping) {
        if (activeRecipe != null) {
            selectedRecipe = null
        } else if (showShopping) {
            showShopping = false
        } else {
            showFridge = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    if (activeRecipe != null || showFridge || showShopping) {
                        IconButton(onClick = {
                            if (activeRecipe != null) {
                                selectedRecipe = null
                            } else if (showShopping) {
                                showShopping = false
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
                    Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        Text(
                            text = "Season.",
                            style = androidx.compose.material3.MaterialTheme.typography.titleLarge,
                        )
                        if (activeRecipe != null || showFridge || showShopping || selectedDestination != SeasonDestination.Home) {
                            Text(
                                text = when {
                                    activeRecipe != null -> "Ricetta"
                                    showShopping -> "Lista della spesa"
                                    showFridge -> "Frigo"
                                    else -> selectedDestination.title
                                },
                                style = androidx.compose.material3.MaterialTheme.typography.labelLarge,
                                color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                },
                actions = {
                    if (activeRecipe == null && !showFridge && !showShopping) {
                        TextButton(
                            onClick = {
                                selectedRecipe = null
                                showFridge = false
                                showShopping = true
                            },
                        ) {
                            Text("Lista")
                        }
                        TextButton(
                            onClick = {
                                selectedRecipe = null
                                showShopping = false
                                showFridge = true
                            },
                        ) {
                            Text("Frigo")
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = androidx.compose.material3.MaterialTheme.colorScheme.background.copy(alpha = 0.96f),
                ),
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = androidx.compose.material3.MaterialTheme.colorScheme.surface.copy(alpha = 0.96f),
                tonalElevation = 0.dp,
            ) {
                SeasonDestination.entries.forEach { destination ->
                    val selected = selectedDestination == destination
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            selectedRecipe = null
                            showFridge = false
                            showShopping = false
                            selectedDestination = destination
                        },
                        icon = {
                            Text(
                                if (selected) "●" else "○",
                                fontWeight = FontWeight.Bold,
                            )
                        },
                        label = { Text(destination.label) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = androidx.compose.material3.MaterialTheme.colorScheme.primary,
                            selectedTextColor = androidx.compose.material3.MaterialTheme.colorScheme.onSurface,
                            indicatorColor = androidx.compose.material3.MaterialTheme.colorScheme.primary.copy(alpha = 0.14f),
                            unselectedIconColor = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
                        ),
                    )
                }
            }
        },
    ) { padding ->
        SeasonCanvas(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            if (activeRecipe != null) {
                RecipeDetailScreen(
                    recipe = activeRecipe,
                    recipeStateViewModel = recipeStateViewModel,
                    shoppingViewModel = shoppingViewModel,
                    onOpenShopping = {
                        selectedRecipe = null
                        showFridge = false
                        showShopping = true
                    },
                )
            } else if (showShopping) {
                ShoppingScreen(shoppingViewModel = shoppingViewModel)
            } else if (showFridge) {
                FridgeScreen(
                    fridgeViewModel = fridgeViewModel,
                    shoppingViewModel = shoppingViewModel,
                    onRecipeSelected = { selectedRecipe = it },
                    onOpenShopping = {
                        showFridge = false
                        showShopping = true
                    },
                )
            } else {
                when (selectedDestination) {
                    SeasonDestination.Home -> HomeScreen(onRecipeSelected = { selectedRecipe = it })
                    SeasonDestination.Search -> SearchScreen(onRecipeSelected = { selectedRecipe = it })
                    SeasonDestination.Create -> CreateScreen(
                        onRecipePublished = { selectedRecipe = it },
                    )
                    SeasonDestination.Today -> TodayScreen()
                    SeasonDestination.Profile -> ProfileScreen(
                        profile = profile,
                        onRecipeSelected = { selectedRecipe = it },
                        onLogout = {
                            recipeStateViewModel.clearLocalRecipeStateOnLogout()
                            fridgeViewModel.clearLocalStateOnLogout()
                            shoppingViewModel.clearLocalStateOnLogout()
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
            modifier = Modifier.padding(top = 4.dp),
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
    SeasonPanel(prominent = action != null) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SeasonKicker(text = title)
                Text(
                    text = body,
                    style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
                    color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (action != null && onAction != null) {
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

@Composable
internal fun SeasonMetricPill(label: String, value: String) {
    SeasonPill(
        text = "$value $label",
        emphasis = SeasonPillEmphasis.Primary,
    )
}

@Composable
internal fun EnvironmentCard() {
    val environment = SeasonEnvironment.current
    SeasonPanel(prominent = true) {
        SeasonKicker(text = "Ambiente ${environment.kind}")
        Text(
            text = if (environment.isConfigured) {
                "Supabase configurato per questo build type."
            } else {
                "Configura la anon key con Gradle property o variabile ambiente prima dei test backend."
            },
            style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
            color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
