class HomeState {
  final bool isLoading;
  final int receivedCount;
  final int sentCount;
  final String? errorMessage;

  const HomeState({
    this.isLoading = true,
    this.receivedCount = 0,
    this.sentCount = 0,
    this.errorMessage,
  });

  HomeState copyWith({
    bool? isLoading,
    int? receivedCount,
    int? sentCount,
    String? errorMessage,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      receivedCount: receivedCount ?? this.receivedCount,
      sentCount: sentCount ?? this.sentCount,
      errorMessage: errorMessage,
    );
  }
}
