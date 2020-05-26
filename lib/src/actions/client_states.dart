enum SimpleGoalState { PENDING, ACTIVE, DONE }
enum SimpleClientGoalState {
  PENDING,
  ACTIVE,
  RECALLED,
  REJECTED,
  PREEMPTED,
  ABORTED,
  SUCCEEDED,
  LOST
}
enum CommState {
  WAITING_FOR_GOAL_ACK,
  PENDING,
  ACTIVE,
  WAITING_FOR_RESULT,
  WAITING_FOR_CANCEL_ACK,
  RECALLING,
  PREEMPTING,
  DONE
}

extension SimpleGoalStateToString on SimpleGoalState {
  String get string {
    switch (this) {
      case SimpleGoalState.PENDING:
        return 'PENDING';
      case SimpleGoalState.ACTIVE:
        return 'ACTIVE';
      case SimpleGoalState.DONE:
        return 'DONE';
      default:
        return 'DONE';
    }
  }
}

extension SimpleClientGoalStateToString on SimpleClientGoalState {
  String get string {
    switch (this) {
      case SimpleClientGoalState.PENDING:
        return 'PENDING';
      case SimpleClientGoalState.ACTIVE:
        return 'ACTIVE';
      case SimpleClientGoalState.RECALLED:
        return 'RECALLED';
      case SimpleClientGoalState.REJECTED:
        return 'REJECTED';
      case SimpleClientGoalState.PREEMPTED:
        return 'PREEMPTED';
      case SimpleClientGoalState.ABORTED:
        return 'ABORTED';
      case SimpleClientGoalState.SUCCEEDED:
        return 'SUCCEEDED';
      case SimpleClientGoalState.LOST:
        return 'LOST';
      default:
        return 'LOST';
    }
  }
}

extension CommStateAsInt on CommState {
  int get asInt {
    switch (this) {
      case CommState.WAITING_FOR_GOAL_ACK:
        return 0;
      case CommState.PENDING:
        return 1;
      case CommState.ACTIVE:
        return 2;
      case CommState.WAITING_FOR_RESULT:
        return 3;
      case CommState.WAITING_FOR_CANCEL_ACK:
        return 4;
      case CommState.RECALLING:
        return 5;
      case CommState.PREEMPTING:
        return 6;
      case CommState.DONE:
        return 7;
      default:
        return 7;
    }
  }
}
