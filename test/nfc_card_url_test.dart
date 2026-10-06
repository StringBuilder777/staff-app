import 'package:flutter_test/flutter_test.dart';
import 'package:staff_app/services/nfc_service.dart';

const _token = '0f8fad5b-d9cb-469f-a165-70867728950e';
const _payload = 'staffapp:nfc:$_token';

void main() {
  test('the card address carries the event and the token after #', () {
    expect(
      NfcService.cardUrl(
        _payload,
        event: NfcCardEvent.sitec,
        base: 'https://staff.test',
      ),
      'https://staff.test/#s/$_token',
    );
    expect(
      NfcService.cardUrl(
        _payload,
        event: NfcCardEvent.hackathon,
        base: 'https://staff.test/',
      ),
      'https://staff.test/#h/$_token',
    );
  });

  test('an address that would not fit an NTAG213 is not used', () {
    // 38 caracteres entre dominio y ruta llenan los 137 bytes de una NTAG213.
    String? withPage(int length) => NfcService.cardUrl(
      _payload,
      event: NfcCardEvent.sitec,
      base: 'https://${'x' * length}',
    );

    expect(withPage(38), isNotNull);
    expect(withPage(39), isNull);
  });

  test('without a page or a Staff credential the card has no address', () {
    // Sin `--dart-define=CARD_WEB_URL` no hay página y las tarjetas se
    // escriben como siempre.
    expect(NfcService.cardUrl(_payload, event: NfcCardEvent.sitec), isNull);
    expect(
      NfcService.cardUrl(
        'staffapp:nfc:no-es-un-token',
        event: NfcCardEvent.sitec,
        base: 'https://staff.test',
      ),
      isNull,
    );
    expect(
      NfcService.cardUrl(
        'otro texto',
        event: NfcCardEvent.sitec,
        base: 'https://staff.test',
      ),
      isNull,
    );
  });
}
