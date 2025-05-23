{
  lib,
  stdenv,
  rustPlatform,
  fetchCrate,
  fixDarwinDylibNames,
  haskellPackages,
}:

let
  pin = lib.importJSON ./pin.json;
in

rustPlatform.buildRustPackage {
  inherit (pin) pname version;

  src = fetchCrate pin;

  # upstream doesn't ship a Cargo.lock, is generated by the update script
  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  cargoLock.lockFile = ./Cargo.lock;

  outputs = [
    "out"
    "dev"
  ];

  # Headers are not handled by cargo nor buildRustPackage
  postInstall = ''
    install -Dm644 include/rure.h -t "$dev/include"
  '';

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    fixDarwinDylibNames
  ];

  passthru = {
    updateScript = ./update.sh;
    tests.haskell-bindings = haskellPackages.regex-rure;
  };

  meta = {
    description = "C API for Rust's regular expression library";
    homepage = "https://crates.io/crates/rure";
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    maintainers = [ lib.maintainers.sternenseemann ];
  };
}
