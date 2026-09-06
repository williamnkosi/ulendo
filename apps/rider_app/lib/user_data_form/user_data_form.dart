import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:form_validator/form_validator.dart';
import 'package:ulendo_core/ulendo_core.dart';
import 'package:ulendo_models/ulendo_models.dart';

class UserDataForm extends StatefulWidget {
  final UserModel? userProfile;

  const UserDataForm({super.key, this.userProfile});

  @override
  State<UserDataForm> createState() => _UserDataFormState();
}

class _UserDataFormState extends State<UserDataForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  final _requiredValidator = ValidationBuilder().required('Required').build();

  @override
  void initState() {
    super.initState();
    _setFormValues(widget.userProfile);
  }

  @override
  void didUpdateWidget(covariant UserDataForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProfile != widget.userProfile) {
      _setFormValues(widget.userProfile);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _setFormValues(UserModel? user) {
    _firstNameController.text = user?.firstName ?? '';
    _lastNameController.text = user?.lastName ?? '';
    _phoneNumberController.text = user?.phoneNumber ?? '';
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('You must be signed in to continue.')),
        );
      return;
    }

    context.read<UserDataBloc>().add(
      UserDataUpdated(
        uid: uid,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        profileImageUrl: widget.userProfile?.profileImageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    return BlocListener<UserDataBloc, UserDataState>(
      listenWhen: (previous, current) =>
          current.status == UserDataStatus.failure,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Failed to save profile. Please try again.'),
            ),
          );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Complete Your Profile')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: BlocBuilder<UserDataBloc, UserDataState>(
                        builder: (context, state) {
                          final isLoading =
                              state.status == UserDataStatus.loading;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Finish setting up your account',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please add the missing profile details before continuing.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                initialValue: authUser?.email ?? '',
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _firstNameController,
                                enabled: !isLoading,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'First Name',
                                ),
                                validator: _requiredValidator,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _lastNameController,
                                enabled: !isLoading,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Last Name',
                                ),
                                validator: _requiredValidator,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneNumberController,
                                enabled: !isLoading,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                ),
                                validator: _requiredValidator,
                              ),
                              const SizedBox(height: 22),
                              ElevatedButton(
                                onPressed: isLoading ? null : _submit,
                                child: Text(
                                  isLoading ? 'Saving...' : 'Save and Continue',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
