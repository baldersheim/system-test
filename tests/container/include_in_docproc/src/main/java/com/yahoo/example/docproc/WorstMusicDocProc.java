// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example.docproc;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.docproc.SimpleDocumentProcessor;

public class WorstMusicDocProc extends SimpleDocumentProcessor {
    public WorstMusicDocProc() {
        System.err.println("WorstMusicDocProc constructor!");
    }

    @Override
    public void process(DocumentPut documentPut) {
	Document document = documentPut.getDocument();
        System.err.println("WorstMusicDocProc.process(DocumentUpdate)");
        document.setFieldValue("title", "Worst music ever");
    }

}
