{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Demo";
      user.email = "demo@example.com";
    };
  };
}
