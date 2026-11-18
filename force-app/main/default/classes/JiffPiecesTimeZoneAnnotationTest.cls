/**
 * `JiffPiecesTimeZoneAnnotation`: the `[...]` time zone part of an RFC 9557 string.
 *
 * The cases are the examples in the doc comments of `jiff::fmt::temporal::TimeZoneAnnotation`
 * and its methods (`fmt/temporal/pieces.rs`). The printed forms are what Jiff 1.0.0 prints
 * for the same annotation in a `Pieces`.
 */
@IsTest
private class JiffPiecesTimeZoneAnnotationTest {
    @IsTest
    static void anAnnotationIsParsedFromANameOrAnOffset() {
        // The example on `TimeZoneAnnotation`.
        JiffPiecesTimeZoneAnnotation named = JiffPieces.parse(
                '2025-01-02T16:47-05[America/New_York]'
            )
            .timeZoneAnnotation();
        Assert.areEqual(JiffPiecesTimeZoneAnnotation.fromName('America/New_York'), named);
        Assert.areEqual(JiffPiecesTimeZoneAnnotationKind.NAMED, named.kind());
        Assert.areEqual('America/New_York', named.name());
        Assert.isNull(named.offset());

        JiffPiecesTimeZoneAnnotation offset = JiffPieces.parse('2025-01-02T16:47-05[-05:00]')
            .timeZoneAnnotation();
        Assert.areEqual(JiffPiecesTimeZoneAnnotation.fromOffset(JiffOffset.fromHours(-5)), offset);
        Assert.areEqual(JiffPiecesTimeZoneAnnotationKind.OFFSET, offset.kind());
        Assert.areEqual(JiffOffset.fromHours(-5), offset.offset());
        Assert.isNull(offset.name());
    }

    @IsTest
    static void aNameNeedNotBeARealTimeZone() {
        // The example on `TimeZoneAnnotation::kind`.
        Assert.areEqual(
            JiffPiecesTimeZoneAnnotation.fromName('Australia/Bluey'),
            JiffPieces.parse('2025-01-02T16:47-05[Australia/Bluey]').timeZoneAnnotation()
        );
    }

    @IsTest
    static void theCriticalFlagIsRecorded() {
        // The example on `TimeZoneAnnotation::is_critical`.
        Assert.isFalse(
            JiffPieces.parse('2025-01-02T16:47-05[Australia/Bluey]')
                .timeZoneAnnotation()
                .isCritical()
        );
        Assert.isTrue(
            JiffPieces.parse('2025-01-02T16:47-05[!Australia/Bluey]')
                .timeZoneAnnotation()
                .isCritical()
        );
        Assert.isTrue(
            JiffPieces.parse('2025-01-02T16:47-05[!-05:00]').timeZoneAnnotation().isCritical()
        );
    }

    @IsTest
    static void toTimeZoneLooksUpANameAndFixesAnOffset() {
        // The example on `TimeZoneAnnotation::to_time_zone`.
        JiffPiecesTimeZoneAnnotation hobart = JiffPieces.parse(
                '2025-01-02T16:47-05[Australia/Hobart]'
            )
            .timeZoneAnnotation();
        Assert.areEqual(JiffTimeZone.get('Australia/Hobart'), hobart.toTimeZone());

        JiffPiecesTimeZoneAnnotation bluey = JiffPieces.parse(
                '2025-01-02T16:47-05[Australia/Bluey]'
            )
            .timeZoneAnnotation();
        try {
            bluey.toTimeZone();
            Assert.fail('expected an unknown time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to find time zone `Australia/Bluey` in time zone database',
                e.getMessage()
            );
        }
        Assert.areEqual(
            JiffTimeZone.fixed(JiffOffset.fromHours(-5)),
            JiffPiecesTimeZoneAnnotation.fromOffset(JiffOffset.fromHours(-5)).toTimeZone()
        );
        // The critical flag makes no difference to the lookup.
        Assert.areEqual(
            JiffTimeZone.get('Australia/Hobart'),
            hobart.withCritical(true).toTimeZone()
        );
    }

    @IsTest
    static void anAnnotationPrintsInBracketsWithItsFlag() {
        // Jiff prints `[Africa/Cairo]`, `[!Africa/Cairo]`, `[+02:00]`, `[!-05:30]` and
        // `[+00:00]` for these annotations in a `Pieces`; see `JiffTemporalPrinterTest`.
        JiffPiecesTimeZoneAnnotation cairo = JiffPiecesTimeZoneAnnotation.fromName('Africa/Cairo');
        Assert.areEqual('[Africa/Cairo]', cairo.toString());
        Assert.areEqual('[!Africa/Cairo]', cairo.withCritical(true).toString());
        Assert.areEqual('[Africa/Cairo]', cairo.withCritical(true).withCritical(false).toString());
        Assert.areEqual(
            '[+02:00]',
            JiffPiecesTimeZoneAnnotation.fromOffset(JiffOffset.fromHours(2)).toString()
        );
        Assert.areEqual(
            '[!-05:30]',
            JiffPiecesTimeZoneAnnotation.fromOffset(JiffOffset.fromSeconds(-19800))
                .withCritical(true)
                .toString()
        );
        Assert.areEqual(
            '[+00:00]',
            JiffPiecesTimeZoneAnnotation.fromOffset(JiffOffset.UTC).toString()
        );
    }

    @IsTest
    static void equalityCoversTheKindTheValueAndTheFlag() {
        JiffPiecesTimeZoneAnnotation cairo = JiffPiecesTimeZoneAnnotation.fromName('Africa/Cairo');
        JiffPiecesTimeZoneAnnotation plusTwo = JiffPiecesTimeZoneAnnotation.fromOffset(
            JiffOffset.fromHours(2)
        );
        Assert.areEqual(cairo, JiffPiecesTimeZoneAnnotation.fromName('Africa/Cairo'));
        Assert.areEqual(
            cairo.hashCode(),
            JiffPiecesTimeZoneAnnotation.fromName('Africa/Cairo').hashCode()
        );
        Assert.areEqual(
            plusTwo,
            JiffPiecesTimeZoneAnnotation.fromOffset(JiffOffset.fromSeconds(7200))
        );
        Assert.areEqual(
            plusTwo.hashCode(),
            JiffPiecesTimeZoneAnnotation.fromOffset(JiffOffset.fromSeconds(7200)).hashCode()
        );
        Assert.areNotEqual(cairo, plusTwo);
        Assert.areNotEqual(plusTwo, cairo);
        Assert.areNotEqual(cairo, cairo.withCritical(true));
        Assert.areNotEqual(cairo, JiffPiecesTimeZoneAnnotation.fromName('africa/cairo'));
        Assert.areNotEqual(
            plusTwo,
            JiffPiecesTimeZoneAnnotation.fromOffset(JiffOffset.fromHours(3))
        );
        Assert.isFalse(cairo.equals('Africa/Cairo'));
        Assert.isFalse(cairo.equals(null));
    }

    @IsTest
    static void aNameOrAnOffsetIsRequired() {
        for (Integer attempt = 0; attempt < 2; attempt++) {
            try {
                if (attempt == 0) {
                    String noName = null;
                    JiffPiecesTimeZoneAnnotation.fromName(noName);
                } else {
                    JiffOffset noOffset = null;
                    JiffPiecesTimeZoneAnnotation.fromOffset(noOffset);
                }
                Assert.fail('expected a missing value to be rejected, attempt ' + attempt);
            } catch (JiffException e) {
                Assert.areEqual('a time zone annotation needs a name or an offset', e.getMessage());
            }
        }
    }

    @IsTest
    static void theCriticalFlagMustNotBeNull() {
        JiffPiecesTimeZoneAnnotation cairo = JiffPiecesTimeZoneAnnotation.fromName('Africa/Cairo');
        try {
            cairo.withCritical(null);
            Assert.fail('expected a null critical flag to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the critical flag must be true or false, not null', e.getMessage());
        }
        Assert.areEqual('[Africa/Cairo]', cairo.toString());
    }
}
