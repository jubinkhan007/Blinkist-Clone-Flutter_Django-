from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('progress', '0003_useraudioprogress_userfullbookprogress_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='userfullbookprogress',
            name='current_offset',
            field=models.FloatField(default=0.0),
        ),
    ]
