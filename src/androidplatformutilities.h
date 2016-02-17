/***************************************************************************
                            androidplatformutilities.h  -  utilities for qfield

                              -------------------
              begin                : February 2016
              copyright            : (C) 2016 by Matthias Kuhn
              email                : matthias@opengis.ch
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#ifndef ANDROIDPLATFORMUTILITIES_H
#define ANDROIDPLATFORMUTILITIES_H

#include "platformutilities.h"
#include <QAndroidJniObject>

class AndroidPlatformUtilities : public PlatformUtilities
{
  public:
    AndroidPlatformUtilities();

    virtual QString configDir() const;
    virtual QString shareDir() const;

  private:
    QMap<QString, QString> getIntentExtras( QStringList );
    QString getIntentExtra( QString, QAndroidJniObject=0 );
    QAndroidJniObject getNativeIntent();
    QAndroidJniObject getNativeExtras();
};

#endif // ANDROIDPLATFORMUTILITIES_H