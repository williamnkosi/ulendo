import 'package:flutter_bloc/flutter_bloc.dart';

import 'ride_event.dart';
import 'ride_state.dart';
import 'ride_repository.dart';

class RideBloc extends Bloc<RideEvent, RideState> {
  final RideRepository _rideRepository;

  RideBloc({required RideRepository rideRepository})
    : _rideRepository = rideRepository,
      super(const RideInitial()) {
    on<RequestRideEvent>(_onRequestRide);
    on<CancelRideEvent>(_onCancelRide);
    on<GetRideStatusEvent>(_onGetRideStatus);
    on<GetActiveRideEvent>(_onGetActiveRide);
    on<CompleteRideEvent>(_onCompleteRide);
  }

  Future<void> _onRequestRide(
    RequestRideEvent event,
    Emitter<RideState> emit,
  ) async {
    // TODO: Implement requestRide logic
  }

  Future<void> _onCancelRide(
    CancelRideEvent event,
    Emitter<RideState> emit,
  ) async {
    // TODO: Implement cancelRide logic
  }

  Future<void> _onGetRideStatus(
    GetRideStatusEvent event,
    Emitter<RideState> emit,
  ) async {
    // TODO: Implement getRideStatus logic
  }

  Future<void> _onGetActiveRide(
    GetActiveRideEvent event,
    Emitter<RideState> emit,
  ) async {
    // TODO: Implement getActiveRide logic
  }

  Future<void> _onCompleteRide(
    CompleteRideEvent event,
    Emitter<RideState> emit,
  ) async {
    // TODO: Implement completeRide logic
  }
}
