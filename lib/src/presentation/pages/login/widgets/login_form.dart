import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/typography/app_text.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthBloc>().add(
      LoginSubmitted(
        username: _usernameController.text,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.select(
      (AuthBloc bloc) => bloc.state.isSubmitting,
    );
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == AuthStatus.authenticated,
      // Only an accepted sign-in should offer to save the password; doing it on
      // every submit asks the password manager to store rejected credentials.
      listener: (context, state) => TextInput.finishAutofillContext(),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                enabled: !isSubmitting,
                decoration: const InputDecoration(
                  labelText: AppStrings.usernameLabel,
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? AppStrings.usernameRequired
                    : null,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              SizedBox(height: context.spacing.lg),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                enabled: !isSubmitting,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: AppStrings.passwordLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? AppStrings.showPassword
                        : AppStrings.hidePassword,
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (value) => (value == null || value.isEmpty)
                    ? AppStrings.passwordRequired
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              SizedBox(height: context.spacing.xl),
              FilledButton(
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? SizedBox.square(
                        dimension: context.sizes.iconMd,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : LabelText(
                        AppStrings.loginButton,
                        color: context.color.onPrimary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
