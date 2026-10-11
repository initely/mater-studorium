.PHONY: get gen fmt lint test check

get:
	flutter pub get

# build_runner подключается позже (freezed/json_serializable/drift); до тех пор цель не падает.
gen:
	@if grep -q '^[[:space:]]*build_runner:' pubspec.yaml; then \
		dart run build_runner build --delete-conflicting-outputs; \
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
