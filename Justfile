# Justfile for PrismatIQ development tasks
# Usage:
#  - Enter nix shell: `nix develop`
#  - Then run: `just test` or `just setup`

setup:
    @echo "Installing shards..."
    shards install

test:
    @echo "Running specs (requires nix develop)"
    shards install || true
    crystal spec -I src --color -v

bench:
    @echo "Run benchmark (example)"
    shards install || true
    crystal run bench/benchmark.cr

bench-small:
    @echo "Run small favicon benchmark"
    shards install || true
    crystal run bench/benchmark.cr -- spec/fixtures/favicon_32x32.rgba.bin

generate-fixture:
    @echo "Generate a 32x32 RGBA fixture using Crystal generator"
    scripts/gen_rgba_crystal.cr 32 32 spec/fixtures/favicon_32x32_from_crystal.rgba.bin || true

generate-all-fixtures:
    @echo "Generate canonical fixtures (4x4, 8x8, 32x32)"
    scripts/gen_rgba_crystal.cr 4 4 spec/fixtures/solid_4x4_rgba.bin || true
    scripts/gen_rgba_crystal.cr 8 8 spec/fixtures/palette_threads_8x8.bin || true
    scripts/gen_rgba_crystal.cr 32 32 spec/fixtures/favicon_32x32.rgba.bin || true
