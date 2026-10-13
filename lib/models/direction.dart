enum Direction {
  up,
  down,
  left,
  right;

  int get dx {
    switch (this) {
      case Direction.left:
        return -1;
      case Direction.right:
        return 1;
      default:
        return 0;
    }
  }

  int get dy {
    switch (this) {
      case Direction.up:
        return -1;
      case Direction.down:
        return 1;
      default:
        return 0;
    }
  }

  Direction get opposite {
    switch (this) {
      case Direction.up:
        return Direction.down;
      case Direction.down:
        return Direction.up;
      case Direction.left:
        return Direction.right;
      case Direction.right:
        return Direction.left;
    }
  }
}
