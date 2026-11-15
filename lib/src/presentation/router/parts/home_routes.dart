part of '../router.dart';

RouteBase _homeRoutes() => StatefulShellRoute.indexedStack(
  // Page blocs live here so they survive tab switches.
  builder: (context, state, navigationShell) => MultiBlocProvider(
    providers: [
      BlocProvider<UploadBloc>(create: (_) => sl<UploadBloc>()),
      BlocProvider<FilesBloc>(
        create: (_) => sl<FilesBloc>()..add(const FilesLoaded()),
      ),
    ],
    child: MainShellPage(navigationShell: navigationShell),
  ),
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.upload,
          name: Routes.uploadName,
          builder: (context, state) => const UploadPage(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.files,
          name: Routes.filesName,
          builder: (context, state) => const FilesPage(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.transfers,
          name: Routes.transfersName,
          builder: (context, state) => TransfersPage(
            highlightId: state.uri.queryParameters[Routes.highlightParam],
            highlightToken:
                state.uri.queryParameters[Routes.highlightTokenParam],
          ),
        ),
      ],
    ),
  ],
);
