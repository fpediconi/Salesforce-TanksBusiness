public class BitlyService {
    private static final String BITLY_TOKEN = 'Bearer b1583d5e97ed77be1b4078b45390f4782f7fe44c';
    private static final String BITLY_ENDPOINT = 'https://api-ssl.bitly.com/v4/shorten';

    public static String shortenUrl(String longUrl) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BITLY_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Authorization', BITLY_TOKEN);
        req.setHeader('Content-Type', 'application/json');

        // Armamos el body del request
        Map<String, Object> body = new Map<String, Object>{
            'long_url' => longUrl,
            'domain' => 'bit.ly'
        };
        req.setBody(JSON.serialize(body));

        HttpResponse res = http.send(req);
        Integer statusCode = res.getStatusCode();
        String responseBody = res.getBody();

        if (statusCode == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            return (String) result.get('link');
        }

        // Si Bitly devolvió error de límite mensual alcanzado
        if (responseBody != null && responseBody.containsIgnoreCase('MONTHLY_ENCODE_LIMIT_REACHED')) {
            return '⚠️ Límite mensual de Bitly alcanzado. Integración OK.';
        }

        // Otros errores
        return '⚠️ Error al generar URL corta. Revisar configuración.';
    }


}
