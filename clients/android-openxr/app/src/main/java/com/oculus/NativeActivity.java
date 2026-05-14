// SPDX-License-Identifier: MPL-2.0

package com.oculus;

import android.os.Bundle;
import android.util.Log;

/**
 * Wrapper around android.app.NativeActivity for Meta Quest VR runtime.
 *
 * The Quest runtime checks the activity class name to determine VR focus handling.
 * Using com.oculus.NativeActivity matches the pattern used by Meta's own SDK samples.
 */
public class NativeActivity extends android.app.NativeActivity
{
    private static final String TAG = "OpenXR-NativeActivity";

    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        Log.i(TAG, "onCreate");
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onResume()
    {
        Log.i(TAG, "onResume");
        super.onResume();
    }

    @Override
    protected void onPause()
    {
        Log.i(TAG, "onPause");
        super.onPause();
    }

    @Override
    protected void onDestroy()
    {
        Log.i(TAG, "onDestroy");
        super.onDestroy();
    }
}
