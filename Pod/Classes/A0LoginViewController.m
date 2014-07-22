//
//  A0LoginViewController.m
//  Pods
//
//  Created by Hernan Zalazar on 6/29/14.
//
//

#import "A0LoginViewController.h"

#import "A0ServicesView.h"
#import "A0APIClient.h"
#import "A0Application.h"
#import "A0UserPasswordView.h"
#import "A0SignUpView.h"
#import "A0RecoverPasswordView.h"
#import "A0LoadingView.h"
#import "A0KeyboardEnabledView.h"
#import "A0CompositeAuthView.h"
#import "A0Errors.h"

#import <libextobjc/EXTScope.h>

@implementation NSNotification (UIKeyboardInfo)

- (CGFloat)keyboardAnimationDuration {
    return [[self userInfo][UIKeyboardAnimationDurationUserInfoKey] doubleValue];
}

- (NSUInteger)keyboardAnimationCurve {
    return [[self userInfo][UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
}

- (CGRect)keyboardEndFrame {
    return [[self userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];
}

@end

@interface A0LoginViewController ()

@property (strong, nonatomic) IBOutlet A0ServicesView *smallSocialAuthView;
@property (strong, nonatomic) IBOutlet A0UserPasswordView *databaseAuthView;
@property (strong, nonatomic) IBOutlet A0LoadingView *loadingView;
@property (strong, nonatomic) IBOutlet A0SignUpView *signUpView;
@property (strong, nonatomic) IBOutlet A0RecoverPasswordView *recoverView;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) UIView<A0KeyboardEnabledView> *authView;

@property (strong, nonatomic) NSPredicate *emailPredicate;

- (IBAction)dismiss:(id)sender;

@end

@implementation A0LoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.modalPresentationStyle = UIModalPresentationFormSheet;
        }
        _usesEmail = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSString *emailRegex = @"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}";
    self.emailPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];

    @weakify(self);
    self.authView = [self layoutLoadingView:self.loadingView inContainer:self.containerView];

    self.databaseAuthView.signUpBlock = ^{
        @strongify(self);
        self.authView = [self layoutSignUpInContainer:self.containerView];
    };
    self.databaseAuthView.forgotPasswordBlock = ^{
        @strongify(self);
        self.authView = [self layoutRecoverInContainer:self.containerView];
    };

    A0APIClientError failureBlock = ^(NSError *error){
        NSLog(@"ERROR %@", error);
    };
    A0APIClientSuccess successBlock = ^(id payload) {
        @strongify(self);
        [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
            if (self.authBlock) {
                self.authBlock(self, payload);
            }
        }];
    };
    self.databaseAuthView.loginBlock = ^(NSString *username, NSString *password) {
        [[A0APIClient sharedClient] loginWithUsername:username password:password success:successBlock failure:failureBlock];
    };

    self.signUpView.signUpBlock = ^(NSString *username, NSString *password){
        [[A0APIClient sharedClient] signUpWithUsername:username password:password success:successBlock failure:failureBlock];
    };

    self.recoverView.recoverBlock = ^(NSString *username, NSString *password) {
        [[A0APIClient sharedClient] changePassword:password forUsername:username success:^(id payload) {
            @strongify(self);
            self.authView = [self layoutDatabaseOnlyAuthViewInContainer:self.containerView];
        } failure:failureBlock];
    };

    self.signUpView.cancelBlock = ^{
        @strongify(self);
        self.authView = [self layoutDatabaseOnlyAuthViewInContainer:self.containerView];
    };
    self.recoverView.cancelBlock = ^{
        @strongify(self);
        self.authView = [self layoutDatabaseOnlyAuthViewInContainer:self.containerView];
    };

    self.databaseAuthView.validateBlock = ^BOOL(NSString *username, NSString *password, NSError **error) {
        @strongify(self);
        BOOL validUsername = [self validateUsername:username];
        BOOL validPassword = password.length > 0;
        if (!validUsername && !validPassword) {
            *error = [A0Errors invalidLoginCredentialsUsingEmail:self.usesEmail];
            return NO;
        }
        if (validUsername && !validPassword) {
            *error = [A0Errors invalidLoginPassword];
            return NO;
        }
        if (!validUsername && validPassword) {
            *error = [A0Errors invalidLoginUsernameUsingEmail:self.usesEmail];
            return NO;
        }
        return YES;
    };

    self.signUpView.validateBlock = ^BOOL(NSString *username, NSString *password, NSError **error) {
        @strongify(self);
        BOOL validUsername = [self validateUsername:username];
        BOOL validPassword = password.length > 0;
        if (!validUsername && !validPassword) {
            *error = [A0Errors invalidSignUpCredentialsUsingEmail:self.usesEmail];
            return NO;
        }
        if (validUsername && !validPassword) {
            *error = [A0Errors invalidSignUpPassword];
            return NO;
        }
        if (!validUsername && validPassword) {
            *error = [A0Errors invalidSignUpUsernameUsingEmail:self.usesEmail];
            return NO;
        }
        return YES;
    };

    self.recoverView.validateBlock = ^BOOL(NSString *username, NSString *password, NSString *repeatPassword, NSError **error) {
        @strongify(self);
        BOOL validUsername = [self validateUsername:username];
        BOOL validPassword = password.length > 0;
        BOOL validRepeat = repeatPassword.length > 0 && [password isEqualToString:repeatPassword];
        if (!validUsername && (!validPassword || !validRepeat)) {
            *error = [A0Errors invalidChangePasswordCredentialsUsingEmail:self.usesEmail];
            return NO;
        }
        if (validUsername && !validPassword && !validRepeat) {
            *error = [A0Errors invalidChangePasswordRepeatPasswordAndPassword];
            return NO;
        }
        if (validUsername && validPassword && !validRepeat) {
            *error = [A0Errors invalidChangePasswordRepeatPassword];
            return NO;
        }
        if (validUsername && !validPassword && validRepeat) {
            *error = [A0Errors invalidChangePasswordPassword];
            return NO;
        }
        if (!validUsername && validPassword && validRepeat) {
            *error = [A0Errors invalidChangePasswordUsernameUsingEmail:self.usesEmail];
            return NO;
        }
        return YES;
    };

    [[A0APIClient sharedClient] fetchAppInfoWithSuccess:^(A0Application *application) {
        @strongify(self);
        [[A0APIClient sharedClient] configureForApplication:application];
        if ([application hasDatabaseConnection]) {
            self.authView = [self layoutDatabaseOnlyAuthViewInContainer:self.containerView];
//            self.smallSocialAuthView.serviceNames = @[@"facebook", @"twitter"];
//            self.authView = [self layoutFullAuthViewInContainer:self.containerView];
        } else {
            //Layout only social or error
        }
    } failure:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (void)dismiss:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)keyboardWillBeShown:(NSNotification *)notification {
    CGRect keyboardFrame = [self.view convertRect:[notification keyboardEndFrame] fromView:nil];
    CGFloat animationDuration = [notification keyboardAnimationDuration];
    NSUInteger animationCurve = [notification keyboardAnimationCurve];
    CGRect buttonFrame = [self.authView rectToKeepVisibleInView:self.view];
    CGRect frame = self.view.frame;
    CGFloat newY = keyboardFrame.origin.y - (buttonFrame.origin.y + buttonFrame.size.height);
    frame.origin.y = MIN(newY, 0);
    [UIView animateWithDuration:animationDuration delay:0.0f options:animationCurve animations:^{
        self.view.frame = frame;
    } completion:nil];
}

- (void)keyboardWillBeHidden:(NSNotification *)notification {
    CGFloat animationDuration = [notification keyboardAnimationDuration];
    NSUInteger animationCurve = [notification keyboardAnimationCurve];
    CGRect frame = self.view.frame;
    frame.origin.y = 0;
    [UIView animateWithDuration:animationDuration delay:0.0f options:animationCurve animations:^{
        self.view.frame = frame;
    } completion:nil];
}

- (void)hideKeyboard:(id)sender {
    [self.authView hideKeyboard];
}

#pragma mark - Validation

- (BOOL)validateUsername:(NSString *)username {
    if (self.usesEmail) {
        return [self.emailPredicate evaluateWithObject:username];
    } else {
        return username.length > 0;
    }
}

#pragma mark - Utility methods

- (UIView<A0KeyboardEnabledView> *)layoutRecoverInContainer:(UIView *)containerView {
    UIView<A0KeyboardEnabledView> *recoverView = self.recoverView;
    recoverView.translatesAutoresizingMaskIntoConstraints = NO;
    [self layoutAuthView:recoverView centeredInContainerView:containerView];
    [self animateFromView:self.authView toView:recoverView withTitle:NSLocalizedString(@"Reset Password", nil)];
    return recoverView;
}

- (UIView<A0KeyboardEnabledView> *)layoutSignUpInContainer:(UIView *)containerView {
    UIView<A0KeyboardEnabledView> *signUpView = self.signUpView;
    signUpView.translatesAutoresizingMaskIntoConstraints = NO;
    [self layoutAuthView:signUpView centeredInContainerView:containerView];
    [self animateFromView:self.authView toView:signUpView withTitle:NSLocalizedString(@"Sign Up", nil)];
    return signUpView;
}

- (UIView<A0KeyboardEnabledView> *)layoutLoadingView:(A0LoadingView *)loadingView inContainer:(UIView *)containerView {
    loadingView.translatesAutoresizingMaskIntoConstraints = NO;
    [self layoutAuthView:loadingView centeredInContainerView:containerView];
    return loadingView;
}

- (void)layoutAuthView:(UIView *)authView centeredInContainerView:(UIView *)containerView {
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:authView];
    [containerView addConstraint:[NSLayoutConstraint constraintWithItem:containerView
                                                              attribute:NSLayoutAttributeCenterX
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:authView
                                                              attribute:NSLayoutAttributeCenterX
                                                             multiplier:1.0f
                                                               constant:0.0f]];
    [containerView addConstraint:[NSLayoutConstraint constraintWithItem:containerView
                                                              attribute:NSLayoutAttributeCenterY
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:authView
                                                              attribute:NSLayoutAttributeCenterY
                                                             multiplier:1.0f
                                                               constant:0.0f]];
    NSDictionary *views = NSDictionaryOfVariableBindings(authView);
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[authView]|" options:0 metrics:nil views:views]];
}

- (UIView<A0KeyboardEnabledView> *)layoutDatabaseOnlyAuthViewInContainer:(UIView *)containerView {
    UIView<A0KeyboardEnabledView> *userPassView = self.databaseAuthView;
    userPassView.translatesAutoresizingMaskIntoConstraints = NO;
    [self layoutAuthView:userPassView centeredInContainerView:containerView];
    [self animateFromView:self.authView toView:userPassView withTitle:NSLocalizedString(@"Login", nil)];
    return userPassView;
}

- (UIView<A0KeyboardEnabledView> *)layoutFullAuthViewInContainer:(UIView *)containerView {
    A0CompositeAuthView *authView = [[A0CompositeAuthView alloc] initWithFirstView:self.smallSocialAuthView
                                                                     andSecondView:self.databaseAuthView];
    authView.delegate = self.databaseAuthView;
    [self layoutAuthView:authView centeredInContainerView:containerView];
    [self animateFromView:self.authView toView:authView withTitle:NSLocalizedString(@"Login", nil)];
    return authView;
}

- (void)animateFromView:(UIView *)fromView toView:(UIView *)toView withTitle:(NSString *)title {
    fromView.alpha = 1.0f;
    toView.alpha = 0.0f;
    [UIView animateWithDuration:0.5f animations:^{
        toView.alpha = 1.0f;
        fromView.alpha = 0.0f;
        self.titleLabel.text = title;
    } completion:^(BOOL finished) {
        [fromView removeFromSuperview];
    }];
}
@end
