namespace parasol:text;

public class Character {
	public static boolean isSpace(byte b) {
		switch (b) {
		case	' ':
		case	'\t':
		case	'\n':
		case	'\v':
		case	'\r':
			return true;
			
		default:
			return false;
		}
		return false;
	}
}
