{ pkgs, lib, ... }:
let

  customSettings = {
    pageInfo = {
      title = "My Custom Dashy Title";
    };

    sections = [
      {
        name = "My Section";
        items = [
          {
            name = "NixOS";
            url = "https://nixos.org";
          }
        ];
      }
    ];
  };

  yamlFormat = pkgs.formats.yaml { };

  customSettingsYaml = yamlFormat.generate "custom-conf.yaml" customSettings;
in
{
  name = "dashy";
  meta.maintainers = [ lib.maintainers.therealgramdalf ];

  nodes = {
    machine1 =
      { config, ... }:
      {
        services.dashy = {
          enable = true;
          virtualHost = {
            enableNginx = true;
            domain = "dashy.local";
          };
        };

        networking.extraHosts = "127.0.0.1 dashy.local";

        services.nginx.virtualHosts."${config.services.dashy.virtualHost.domain}".listen = [
          {
            addr = "127.0.0.1";
            port = 80;
          }
        ];
      };

    machine2 =
      { config, pkgs, ... }:
      {
        services.dashy = {
          enable = true;
          package = pkgs.dashy-ui.override {
            settings = customSettings;
          };
          virtualHost = {
            enableNginx = true;
            domain = "dashy.local";
          };
        };

        networking.extraHosts = "127.0.0.1 dashy.local";

        services.nginx.virtualHosts."${config.services.dashy.virtualHost.domain}".listen = [
          {
            addr = "127.0.0.1";
            port = 80;
          }
        ];
      };
  };

  # Note that without javascript, the title is always `Dashy` regardless of your `settings.pageInfo.title`
  # This test could be improved to include checking that user settings are applied properly with proper tools/requests
  # and/or by checking the static site files directly instead
  testScript = ''
    machine1.wait_for_unit("nginx.service")
    machine1.wait_for_open_port(80)

    actual1 = machine1.succeed("curl -v --stderr - http://dashy.local/", timeout=10)
    expected1 = "<title>Dashy</title>"
    assert expected1 in actual1, \
      f"unexpected reply from Dashy, expected: '{expected1}' got: '{actual1}'"

    machine2.wait_for_unit("nginx.service")
    machine2.wait_for_open_port(80)

    actual2 = machine2.succeed("curl -s --stderr - http://dashy.local/conf.yml", timeout=10).strip()
    expected2 = machine2.succeed("cat ${customSettingsYaml}").strip()

    assert expected2 == actual2, \
      f"unexpected reply from Dashy, expected: '{expected2}' got: '{actual2}'"
  '';
}
