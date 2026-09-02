from datetime import date

from rest_framework import serializers


class ReportDateRangeSerializer(serializers.Serializer):
    start_date = serializers.DateField(required=False)
    end_date = serializers.DateField(required=False)

    def validate(self, attrs):
        today = date.today()

        start_date = attrs.get(
            'start_date',
            date(today.year, 1, 1)
        )

        end_date = attrs.get(
            'end_date',
            date(today.year, 12, 31)
        )

        if start_date > end_date:
            raise serializers.ValidationError({
                'date_range':
                    'start_date phải nhỏ hơn hoặc bằng end_date.'
            })

        attrs['start_date'] = start_date
        attrs['end_date'] = end_date

        return attrs