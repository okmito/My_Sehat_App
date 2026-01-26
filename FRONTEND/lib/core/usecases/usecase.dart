import '../error/failures.dart';

// dartz is not in dependencies, I should add it or use a Result type.
// Since user didn't specify fpdatz/dartz, I'll stick to a simple Result class or use dartz if standard.
// Actually, I'll add fpdart or dartz.
// For now, I'll use a simple Either-like structure or just Future<T> and throw exceptions controlled?
// No, Clean Architecture usually uses Either.
// I will implement a simple Result class to avoid extra dependency for now, or just add fpdart.
// Let's add fpdart to pubspec in next step if needed, but for now I will define a Result type here.

// Wait, I can just use a sealed class.

sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Error<T> extends Result<T> {
  final Failure failure;
  const Error(this.failure);
}

abstract class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

class NoParams {}
