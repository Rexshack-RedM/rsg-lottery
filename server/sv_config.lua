-- Server-only config: never sent to clients, so the webhook URL stays private
ServerConfig = {}

ServerConfig.Webhook = {
    enabled = true,
    url = '', -- your Discord webhook URL
    color = 10066431,
    footer = 'rsg-lottery',
    footerIcon = '',
    title = '🎟 RSG Lottery',
}
