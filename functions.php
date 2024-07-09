add_action('template_redirect', 'redirect_to_login_page');

function redirect_to_login_page() {
    // Verifica se o usuário não está logado
    if (!is_user_logged_in()) {
        // Redireciona para a página de login
        wp_redirect(wp_login_url());
        exit;
    }
}