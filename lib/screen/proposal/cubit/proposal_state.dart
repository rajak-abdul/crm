import 'package:crm_app/screen/proposal/modal/proposal_modal.dart';


abstract class ProposalState {
  const ProposalState();
}

class ProposalInitial extends ProposalState {}

class ProposalLoading extends ProposalState {}

class ProposalLoaded extends ProposalState {
  final List<Proposal> proposals;

  const ProposalLoaded(this.proposals);
}

class ProposalError extends ProposalState {
  final String message;

  const ProposalError(this.message);
}