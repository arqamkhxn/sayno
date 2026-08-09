class ExecuteExitStrategyUseCase {
  /// Defines what should happen when a session is exited.
  /// This delegates UI routing decisions to the presentation layer.
  Future<ExitRoute> execute({required bool hasReflected, required int sessionDuration}) async {
    // If the user hasn't reflected and the session was extremely short,
    // we might skip the summary.
    if (!hasReflected && sessionDuration < 10) {
      return ExitRoute.directToHome;
    }
    
    // Otherwise, show the optional Exit Summary
    return ExitRoute.showSummary;
  }
}

enum ExitRoute {
  showSummary,
  directToHome,
}
