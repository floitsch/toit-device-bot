import device_bot show *
import device_bot.interpreter show *

main:
  PROGRAM ::= """
    let reminder = true;
    if (reminder) {
      print("Don't forget to look after your noodles!");

      let currentTime = 0;
      while (currentTime < 30000) {
          sleep(1000);
          currentTime = currentTime + 1000;
      }

      print("Remember to put them in the fridge.");
      sleep(17000);
      print("You can do anything you put your mind to!");
    }
  """

  log := []
  functions := [
    Function
        --syntax="sleep(<x>)"
        --description="Sleep x ms"
        --action=:: | args/List |
          ms := args[0]
          log.add "sleep --ms=$ms",
    Function
        --syntax="print(<message>)"
        --description="Print a message"
        --action=:: | args/List |
          message := args[0]
          log.add "print $message",
  ]

  program := parse PROGRAM functions
  program.eval
  print log

  PROGRAM2 ::= """
    let remind = true;
    let message = false;

    if (remind) {
      let noodlesDone = false;
      let timeToRemind = 30000;

      sleep(timeToRemind);

      while (!noodlesDone) {
        sleep(20000);
        message = true;
        noodlesDone = true;
      }
    }

    if (message) {
      print("Way to go, champ!");
    }"""
  log = []
  program = parse PROGRAM2 functions
  program.eval
  print log

  PROGRAM3 ::= """
    let message = "Don't forget about your noodles! Keep up the good work!";
    sleep(30000);
    print(message);
    sleep(20000);
    print("You're doing great!");
  """
  log = []
  program = parse PROGRAM3 functions
  program.eval
  print log
