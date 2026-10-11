.PHONY: get gen fmt lint test check

get:
	flutter pub get

# build_runner подключён (drift). `flutter pub run` вместо `dart run`: берёт Dart SDK из Flutter, а не из PATH.
# Флаг --delete-conflicting-outputs в новом build_runner удалён (игнорируется с предупреждением).
gen:
	@if grep -q '^[[:space:]]*build_runner:' pubspec.yaml; then \
		flutter pub run build_runner build; \
	else \
		echo "gen: build_runner не подключён в pubspec.yaml, генерировать нечего"; \
	fi

fmt:
	dart format .

lint:
	flutter analyze

test:
	flutter test

check: fmt lint test
