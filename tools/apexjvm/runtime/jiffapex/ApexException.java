package jiffapex;

/** Base of every exception class declared in Apex source. */
public class ApexException extends RuntimeException {
    private String message;

    public ApexException() {
        super();
    }

    public ApexException(String message) {
        super(message);
        this.message = message;
    }

    public ApexException(Exception cause) {
        super(cause);
        this.message = cause == null ? null : cause.getMessage();
    }

    public ApexException(String message, Exception cause) {
        super(message, cause);
        this.message = message;
    }

    @Override
    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getTypeName() {
        return getClass().getSimpleName();
    }

    public String getStackTraceString() {
        StringBuilder sb = new StringBuilder();
        for (StackTraceElement e : getStackTrace()) {
            sb.append(e.toString()).append('\n');
        }
        return sb.toString();
    }
}
