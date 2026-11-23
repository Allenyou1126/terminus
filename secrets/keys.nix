# Public keys only. Private keys never belong in this repository.
let
  hostKeys = {
    lap-fallom = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHjLVkXGVgMnSDIUU2JzlEoSmnF3Z9ycWE67NRhbaX8c";
    lap-yenner = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQ7zqq7DcA4P2IpJdcK3o/bxvH6t3x8BJeQZOfNv4Ky";
    home-ebeling = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4nFJgWYfMzCNjJ7QB+bXMS80GX4kTNpcIuBqKRro8B";
    sha-ali-gaal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDcuUEBsBH4e1vV9p8X0MmeVJru59leEPUrGQsg7rTak";
    lax-rn-riose = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINlhZ1WU6Tmv2rU9qk1u/5v/EbVfwZEuB4Smt2JRcR7k";
    sha-ali-seldon = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILcUwdKInpROskVQd6133q/BmWFK4+73sA4tuOwzJ5rO";
    hkg-dog-darell = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMStY7T72mQ9WVer2KIDdAxjBJKArwjaWFdpsNQGHgku";
  };
in
{
  hostKeys = hostKeys;

  adminKeys = [
    hostKeys.lap-fallom
    hostKeys.lap-yenner
  ];
}
